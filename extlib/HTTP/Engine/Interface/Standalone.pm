package HTTP::Engine::Interface::Standalone;
use HTTP::Engine::Interface
    builder => 'NoEnv',
    writer  => {
        response_line => 1,
        before => {
            finalize => sub {
                my($self, $req, $res) = @_;

                $res->headers->date(time);

                if ($req->_connection->{keepalive_available}) {
                    $res->headers->header( Connection => 'keep-alive' );
                } else {
                    $res->headers->header( Connection => 'close' );
                }
            }
        }
    }
;


use Socket qw(:all);
use IO::Socket::INET ();
use IO::Select       ();

BEGIN {
    if ( $ENV{SMART_COMMENTS} ) {
        Any::Moose::load_class('Smart::Comments');
        Smart::Comments->import;
    }
}

has host => (
    is      => 'ro',
    isa     => 'Str',
    default => '127.0.0.1',
);

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 1978,
);

has keepalive => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has keepalive_timeout => (
    is      => 'ro',
    isa     => 'Int',
    default => 5,
);

# fixme add preforking support using Parallel::Prefork
has fork => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has allowed => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { { '127.0.0.1' => '255.255.255.255' } },
);

has argv => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
);

sub run {
    my ( $self ) = @_;

    if ($self->keepalive && !$self->fork) {
        Carp::croak "set fork=1 if you want to work with keepalive!";
    }

    # Setup socket
    my $daemon = IO::Socket::INET->new(
        Listen    => SOMAXCONN,
        LocalAddr => $self->host,
        LocalPort => $self->port,
        Proto     => 'tcp',
        ReuseAddr => 1,
        Type      => SOCK_STREAM,
    ) or die "Couldn't create daemon: $!";

    my $restart = 0;
    my $parent = $$;
    my $pid    = undef;
    local $SIG{CHLD} = 'IGNORE';

    ### start server
    while (my ($remote, $peername) = $daemon->accept) {
        ### accept : $remote->fileno
        # TODO (Catalyst): get while ( my $remote = $daemon->accept ) to work
        next unless my($method, $uri, $protocol) = $self->_parse_request_line($remote);
        unless (uc $method eq 'RESTART') {
            # Fork
            next if $self->fork && ($pid = fork);
            $self->_handler($remote, $method, $uri, $protocol, $peername);
            if (defined $pid) {
                $daemon->close;
                exit();
            }
        } else {
            ### RESTART
            if ($self->_can_restart($peername)) {
                $restart = 1;
                last;
            }
        }
    } continue {
        close $remote;
    }
    $daemon->close;

    if ($restart) {
        $SIG{CHLD} = 'DEFAULT';
        wait;
        exec $^X, $0, @{ $self->argv };
    }

    exit;
}

sub _handler {
    my($self, $remote, $method, $uri, $protocol, $peername) = @_;

    # Ignore broken pipes as an HTTP server should
    local $SIG{PIPE} = sub { close $remote };

    # We better be careful and just use 1.0
    $protocol = '1.0'; # XXX I don't know about why this needed.

    my $select = IO::Select->new($remote);

    $remote->autoflush(1);

    while (1) {
        # FIXME refactor an HTTP push parser

        my $headers = $self->_parse_header($remote, $protocol);

        my $connection = lc $headers->header("Connection");
        ### connection: $connection

        my $keepalive_available = $self->keepalive
                                  && index( $connection, 'keep-alive' ) > -1
        ;
        ### keepalive_available: $keepalive_available

        $self->_handle_one($remote, $method, $uri, $protocol, $peername, $headers, $keepalive_available);

        if ($keepalive_available) {
            ### waiting keepalive timeout
            last unless $select->can_read($self->keepalive_timeout);

            ### GO! keep alive!
            last unless ($method, $uri, $protocol) = $self->_parse_request_line($remote, 1);
        } else {
            last;
        }
    }

    $remote->read(my $buf, 4096) if $select->can_read(0); # IE hack

    ### close connection
    $remote->close();
}

sub _parse_request_line {
    my($self, $handle, $is_keepalive) = @_;

    # Parse request line
    my $line = $self->_get_line($handle);
    if ($is_keepalive && ($line eq '' || $line eq "\015")) {
        $line = $self->_get_line($handle);
    }
    return ()
      unless my($method, $uri, $protocol) =
      $line =~ m/\A(\w+)\s+(\S+)(?:\s+HTTP\/(\d+(?:\.\d+)?))?\z/;
    return ($method, $uri, $protocol);
}

sub _peeraddr {
    my ($self, $peername) = @_;

    my (undef, $iaddr) = sockaddr_in($peername);
    return inet_ntoa($iaddr) || "127.0.0.1";
}

sub _get_line {
    my($self, $handle) = @_;

    # FIXME use bufferred but nonblocking IO? this is a lot of calls =(
    my $line = '';
    while ($handle->read(my $byte, 1)) {
        last if $byte eq "\012";    # eol
        $line .= $byte;
    }

    # strip \r, \n was already stripped
    $line =~ s/\015$//s;

    $line;
}

# Parse headers
# taken from HTTP::Message, which is unfortunately not really reusable
sub _parse_header {
    my ($self, $remote, $protocol) = @_;

    if ( $protocol >= 1 ) {
        my @hdr;
        while ( length( my $line = $self->_get_line($remote) ) ) {
            if ( $line =~ s/^([^\s:]+)[ \t]*: ?(.*)// ) {
                push( @hdr, $1, $2 );
            }
            elsif ( @hdr && $line =~ s/^([ \t].*)// ) {
                $hdr[-1] .= "\n$1";
            }
            else {
                last;
            }
        }
        HTTP::Headers::Fast->new(@hdr);
    }
    else {
        HTTP::Headers::Fast->new;
    }
}

sub _handle_one {
    my($self, $remote, $method, $uri, $protocol, $peername, $headers, $keepalive_available) = @_;

    local *STDOUT = $remote;
    $self->handle_request(
        uri => URI::WithBase->new(
            do {
                my $u = URI->new($uri);
                $u->scheme('http');
                $u->host($headers->header('Host') || $self->host);
                $u->port($self->port);
                $u->path('/') if $uri =~ m!^https?://!i;
                my $b = $u->clone;
                $b->path_query('/');
                ($u, $b);
            },
        ),
        headers        => $headers,
        _connection => {
            input_handle        => $remote,
            output_handle       => $remote,
            env                 => {},
            keepalive_available => $keepalive_available,
        },
        connection_info => {
            method         => $method,
            address        => $self->_peeraddr($peername),
            port           => $self->port,
            protocol       => "HTTP/$protocol",
            user           => undef,
            _https_info    => undef,
            request_uri    => $uri,
        },
    );
}

sub _can_restart {
    my ($self, $peername) = @_;

    my $peeraddr = _inet_addr($self->_peeraddr($peername));
    my $allowed = $self->allowed;
    for my $ip (keys %{ $allowed }) {
        my $mask = $allowed->{$ip};
        if (($peeraddr & _inet_addr($mask)) == _inet_addr($ip)) {
            return 1
        }
    }
    return 0;
}

sub _inet_addr { unpack "N*", inet_aton($_[0]) }

__INTERFACE__

__END__

=for stopwords Standalone

=head1 NAME

HTTP::Engine::Interface::Standalone - Standalone HTTP Server

=head1 DESCRIPTION

THIS MODULE WILL REMOVE!!

=head1 AUTHOR

Kazuhiro Osawa

