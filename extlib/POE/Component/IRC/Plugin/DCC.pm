package POE::Component::IRC::Plugin::DCC;

use strict;
use warnings;
use Carp;
use File::Basename qw(fileparse);
use POE qw(Driver::SysRW Filter::Line Filter::Stream
           Wheel::ReadWrite Wheel::SocketFactory);
use POE::Component::IRC::Plugin qw(:ALL);
use Socket;

our $VERSION = '6.02';

use constant {
    OUT_BLOCKSIZE  => 1024,   # Send DCC data in 1k chunks
    IN_BLOCKSIZE   => 10_240, # 10k per DCC socket read
    LISTEN_TIMEOUT => 300,    # Five minutes for listening DCCs
};

sub new {
    my ($package) = shift;
    croak "$package requires an even number of arguments" if @_ & 1;
    my %self = @_;
    return bless \%self, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    
    $self->{irc} = $irc;
    
    POE::Session->create(
        object_states => [
            $self => [qw(
                _start
                _dcc_read
                _dcc_failed
                _dcc_timeout
                _dcc_up
                _event_dcc
                _event_dcc_accept
                _event_dcc_chat
                _event_dcc_close
                _event_dcc_resume
            )],
        ],
    );

    $irc->plugin_register($self, 'SERVER', qw(disconnected dcc_request));
    $irc->plugin_register($self, 'USER', qw(dcc dcc_accept dcc_chat dcc_close dcc_resume));
    
    return 1;
}

sub PCI_unregister {
    my ($self) = @_;
    delete $self->{irc};
    delete $self->{$_} for qw(wheelmap dcc);
    $poe_kernel->refcount_decrement($self->{session_id}, __PACKAGE__);
    return 1;
}

sub _start {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $self->{session_id} = $_[SESSION]->ID();
    $kernel->refcount_increment($self->{session_id}, __PACKAGE__);
    return;
}

# set the dcc ports
sub dccports {
    my ($self, $value) = @_;
    $self->{dccports} = $value;
    return;
}

# set the NAT address
sub nataddr {
    my ($self, $value) = @_;
    $self->{nataddr} = $value;
    return;
}

# returns information about a connection
sub dcc_info {
    my ($self, $id) = @_;
    
    if (!$self->{dcc}->{$id}) {
        warn "dcc_info: Unknown wheel ID: $id\n";
        return;
    }

    my %info;
    @info{qw(nick type port file size done peeraddr)}
        = @{ $self->{dcc}->{$id} }{qw(
            nick type port file size done peeraddr
        )};
    return \%info;
}

sub _quote_file {
    my ($file) = @_;

    if ($file =~ /[\s"]/) {
        $file =~ s|"|\\"|g;
        $file = qq{"$file"};
    }
    return $file;
}

sub S_disconnected {
    my ($self) = $_;
    # clean up old cookies for any ignored RESUME requests 
    delete $self->{resuming};
    return PCI_EAT_NONE;
}

sub S_dcc_request {
    my ($self, $irc) = splice @_, 0, 2;
    my ($user, $type, $port, $cookie, $file, $size) = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;
    my $nick = (split /!/, $user)[0];

    if ($type eq 'ACCEPT' && $self->{resuming}->{"$port+$nick"}) {
        # the old cookie has the peer's address
        my $old_cookie = delete $self->{resuming}->{"$port+$nick"};
        $irc->yield(dcc_accept => $old_cookie);
    }
    elsif ($type eq 'RESUME') {
        for my $cookie (values %{ $self->{dcc} }) {
            next if $cookie->{nick} ne $nick;
            next if $cookie->{port} ne $port;
            $file = _quote_file($file);
            $irc->yield(ctcp => $nick => "DCC ACCEPT $file $port $size");
            last;
        }
    }

    return PCI_EAT_NONE;
}

# the U_* handlers are stubs which call our POE event handlers
# so that we can do stuff related to our POE session, e.g.
# create wheels and set alarms/delays

sub U_dcc {
    my ($self, $irc) = splice @_, 0, 2;
    my @args = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;
    $poe_kernel->call($self->{session_id}, _event_dcc => @args);
    return PCI_EAT_NONE;
}

sub U_dcc_accept {
    my ($self, $irc) = splice @_, 0, 2;
    my @args = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;
    $poe_kernel->call($self->{session_id}, _event_dcc_accept => @args);
    return PCI_EAT_NONE;
}

sub U_dcc_chat {
    my ($self, $irc) = splice @_, 0, 2;
    my @args = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;
    $poe_kernel->call($self->{session_id}, _event_dcc_chat => @args);
    return PCI_EAT_NONE;
}

sub U_dcc_close {
    my ($self, $irc) = splice @_, 0, 2;
    my @args = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;
    $poe_kernel->call($self->{session_id}, _event_dcc_close => @args);
    return PCI_EAT_NONE;
}

sub U_dcc_resume {
    my ($self, $irc) = splice @_, 0, 2;
    my @args = map { ref && ${ $_ } } @_;
    $poe_kernel->call($self->{session_id}, _event_dcc_resume => @args);
    return PCI_EAT_NONE;
}

# Attempt to initiate a DCC SEND or CHAT connection with another person.
sub _event_dcc {
    my ($kernel, $self, $nick, $type, $file, $blocksize, $timeout)
        = @_[KERNEL, OBJECT, ARG0..$#_];
    
    if (!defined $type) {
        warn "The 'dcc' event requires at least two arguments\n";
        return;
    }

    my $irc = $self->{irc};
    my ($bindport, $bindaddr, $factory, $port, $addr, $size);

    $type = uc $type;
    if ($type eq 'CHAT') {
        $file = 'chat';   # As per the semi-specification
    }
    elsif ($type eq 'SEND') {
        if (!defined $file) {
            warn "Event 'dcc' requires three arguments for a SEND\n";
            return;
        }
        $size = (stat $file)[7];
        if (!defined $size) {
            $irc->send_event(
                'irc_dcc_error',
                undef,
                "Couldn't get ${file}'s size: $!",
                $nick,
                $type,
                undef,
                $file,
            );
            return;
        }
    }
    
    $bindaddr = $irc->localaddr();
    if ($bindaddr && $bindaddr =~ tr/a-zA-Z.//) {
        $bindaddr = inet_aton($bindaddr);
    }

    if ($self->{dccports}) {
        $bindport = shift @{ $self->{dccports} };
        if (!defined $bindport) {
          warn "dcc: Can't allocate listen port for DCC $type\n";
          return;
        }
    }

    $factory = POE::Wheel::SocketFactory->new(
        BindAddress  => $bindaddr || INADDR_ANY,
        BindPort     => $bindport,
        SuccessEvent => '_dcc_up',
        FailureEvent => '_dcc_failed',
        Reuse        => 'yes',
    );
    
    ($port, $addr) = unpack_sockaddr_in($factory->getsockname());
    $addr = inet_aton($self->{nataddr}) if $self->{nataddr};
  
    if (!defined $addr) {
        warn "dcc: Can't determine our IP address! ($!)\n";
        return;
    }
    $addr = unpack 'N', $addr;

    my $basename = fileparse($file);
    $basename = _quote_file($basename);

    # Tell the other end that we're waiting for them to connect.
    $irc->yield(ctcp => $nick => "DCC $type $basename $addr $port" . ($size ? " $size" : ''));

    # Store the state for this connection.
    $self->{dcc}->{ $factory->ID } = {
        open       => 0,
        nick       => $nick,
        type       => $type,
        file       => $file,
        size       => $size,
        port       => $port,
        addr       => $addr,
        done       => 0,
        blocksize  => ($blocksize || OUT_BLOCKSIZE),
        listener   => 1,
        factory    => $factory,
    };
    
    $kernel->alarm(
        '_dcc_timeout',
        time() + ($timeout || LISTEN_TIMEOUT),
        $factory->ID,
    );
    
    return;
}

# Accepts a proposed DCC connection to another client. See '_dcc_up' for
# the rest of the logic for this.
sub _event_dcc_accept {
    my ($self, $cookie, $myfile) = @_[OBJECT, ARG0, ARG1];

    if (!defined $cookie) {
        warn "The 'dcc_accept' event requires at least one argument\n";
        return;
    }

    if ($cookie->{type} eq 'SEND') {
        $cookie->{type} = 'GET';
        $cookie->{file} = $myfile if defined $myfile;   # filename override
    }

    my $factory = POE::Wheel::SocketFactory->new(
        RemoteAddress => $cookie->{addr},
        RemotePort    => $cookie->{port},
        SuccessEvent  => '_dcc_up',
        FailureEvent  => '_dcc_failed',
    );
  
    $self->{dcc}->{$factory->ID} = $cookie;
    $self->{dcc}->{$factory->ID}->{factory} = $factory;

    return;
}

# Send data over a DCC CHAT connection.
sub _event_dcc_chat {
    my ($self, $id, @data) = @_[OBJECT, ARG0..$#_];
    
    if (!defined $id || !@data) {
        warn "The 'dcc_chat' event requires at least two arguments\n";
        return;
    }

    if (!exists $self->{dcc}->{$id}) {
        warn "dcc_chat: Unknown wheel ID: $id\n";
        return;
    }
    
    if (!exists $self->{dcc}->{$id}->{wheel}) {
        warn "dcc_chat: No DCC wheel for id $id!\n";
        return;
    }
  
    if ($self->{dcc}->{$id}->{type} ne 'CHAT') {
        warn "dcc_chat: id $id isn't associated with a DCC CHAT connection!\n";
        return;
    }

    $self->{dcc}->{$id}->{wheel}->put(join "\n", @data);
    return;
}

# Terminate a DCC connection manually.
sub _event_dcc_close {
    my ($kernel, $self, $id) = @_[KERNEL, OBJECT, ARG0];
    my $irc = $self->{irc};
    
    if (!defined $id) {
        warn "The 'dcc_close' event requires an id argument\n";
        return;
    }

    if (!exists $self->{dcc}->{$id}) {
        warn "dcc_close: Unknown wheel ID: $id\n";
        return;
    }
    
    if (!exists $self->{dcc}->{$id}->{wheel}) {
        warn "dcc_close: No DCC wheel for id $id!\n";
        return;
    }

    # pending data, wait till it has been flushed
    if ($self->{dcc}->{$id}->{wheel}->get_driver_out_octets()) {
        $kernel->delay_set(_event_dcc_close => 2, $id);
        return;
    }

    $irc->send_event(
        'irc_dcc_done',
        $id,
        @{ $self->{dcc}->{$id} }{qw(
            nick type port file size done peeraddr
        )},
    );

    # Reclaim our port if necessary.
    if ($self->{dcc}->{$id}->{listener} && $self->{dccports}) {
        push ( @{ $self->{dccports} }, $self->{dcc}->{$id}->{port} );
    }

    if (exists $self->{dcc}->{$id}->{wheel}) {
        delete $self->{wheelmap}->{$self->{dcc}->{$id}->{wheel}->ID};
        delete $self->{dcc}->{$id}->{wheel};
    }

    delete $self->{dcc}->{$id};
    return;
}

## no critic (InputOutput::RequireBriefOpen)
sub _event_dcc_resume {
    my ($self, $cookie, $myfile) = @_[OBJECT, ARG0, ARG1];
    my $irc = $self->{irc};

    my $sender_file = _quote_file($cookie->{file});
    $cookie->{file} = $myfile if defined $myfile;
    my $size = -s $cookie->{file};
    my $fraction = $size % IN_BLOCKSIZE;
    $size -= $fraction;

    # we need to truncate the whole thing, adjust the size we are
    # requesting to the size we will truncate the file to
    if (open(my $handle, '>>', $cookie->{file})) {
        if (!truncate($handle, $size)) {
            warn "dcc_resume: Can't truncate '$cookie->{file}' to size $size\n";
            return;
        }
        
        $irc->yield(ctcp => $cookie->{nick} => "DCC RESUME $sender_file $cookie->{port} $size");
        
        # save the cookie for later
        $self->{resuming}->{"$cookie->{port}+$cookie->{nick}"} = $cookie;
    }
    
    return;
}

# Accept incoming data on a DCC socket.
sub _dcc_read {
    my ($self, $data, $id) = @_[OBJECT, ARG0, ARG1];
    my $irc = $self->{irc};

    $id = $self->{wheelmap}->{$id};

    if ($self->{dcc}->{$id}->{type} eq 'GET') {
        # Acknowledge the received data.
        print {$self->{dcc}->{$id}->{fh}} $data;
        $self->{dcc}->{$id}->{done} += length $data;
        $self->{dcc}->{$id}->{wheel}->put(
            pack 'N', $self->{dcc}->{$id}->{done}
        );

        # Send an event to let people know about the newly arrived data.
        $irc->send_event(
            'irc_dcc_get',
            $id,
            @{ $self->{dcc}->{$id} }{qw(
                nick port file size done peeraddr
            )},
        );
    }
    elsif ($self->{dcc}->{$id}->{type} eq 'SEND') {
        # Record the client's download progress.
        $self->{dcc}->{$id}->{done} = unpack 'N', substr( $data, -4 );
        
        $irc->send_event(
            'irc_dcc_send',
            $id,
            @{ $self->{dcc}->{$id} }{qw(
                nick port file size done peeraddr
            )},
        );

        # Are we done yet?
        if ($self->{dcc}->{$id}->{done} >= $self->{dcc}->{$id}->{size}) {
            # Reclaim our port if necessary.
            if ( $self->{dcc}->{$id}->{listener} && $self->{dccports}) {
                push @{ $self->{dccports} }, $self->{dcc}->{$id}->{port};
            }

            $irc->send_event(
                'irc_dcc_done',
                $id,
                @{ $self->{dcc}->{$id} }{qw(
                    nick type port file size done peeraddr
                )},
            );
            delete $self->{wheelmap}->{ $self->{dcc}->{$id}->{wheel}->ID };
            delete $self->{dcc}->{$id};
            return;
        }

        # Send the next 'blocksize'-sized packet.
        read $self->{dcc}->{$id}->{fh}, $data,
            $self->{dcc}->{$id}->{blocksize};
        $self->{dcc}->{$id}->{wheel}->put( $data );
    }
    else {
        $irc->send_event(
            'irc_dcc_' . lc $self->{dcc}->{$id}->{type},
            $id,
            @{ $self->{dcc}->{$id} }{qw(nick port)},
            $data,
            $self->{dcc}->{$id}->{peeraddr},
        );
    }
    
    return;
}

# What happens when an attempted DCC connection fails.
sub _dcc_failed {
    my ($self, $operation, $errnum, $errstr, $id) = @_[OBJECT, ARG0 .. ARG3];
    my $irc = $self->{irc};

    if (!exists $self->{dcc}->{$id}) {
        if (exists $self->{wheelmap}->{$id}) {
            $id = $self->{wheelmap}->{$id};
        }
        else {
            warn "_dcc_failed: Unknown wheel ID: $id\n";
            return;
        }
    }
  
    # Reclaim our port if necessary.
    if ( $self->{dcc}->{$id}->{listener} && $self->{dccports}) {
        push ( @{ $self->{dccports} }, $self->{dcc}->{$id}->{port} );
    }

    DCC: {
        last DCC if $errnum != 0;
    
        # Did the peer of a DCC GET connection close the socket after the file
        # transfer finished? If so, it's not really an error.
        if ($self->{dcc}->{$id}->{type} eq 'GET') {
            if ($self->{dcc}->{$id}->{done} < $self->{dcc}->{$id}->{size}) {
                last DCC;
            }
        }

        if ($self->{dcc}->{$id}->{type} =~ /^(GET|CHAT)$/) {
            $irc->send_event(
                'irc_dcc_done',
                $id,
                @{ $self->{dcc}->{$id} }{qw(
                    nick type port file size done peeraddr
                )},
            );

            if ( $self->{dcc}->{$id}->{wheel} ) {
                delete $self->{wheelmap}->{ $self->{dcc}->{$id}->{wheel}->ID };
            }
            delete $self->{dcc}->{$id};
        }
        
        return;
    }
  
    # something went wrong
    if ($errnum == 0 && $self->{dcc}->{$id}->{type} eq 'GET') {
        $errstr = 'Aborted by sender';
    }
    else {
        $errstr = $errstr
            ? $errstr = "$operation error $errnum: $errstr"
            : $errstr = "$operation error $errnum"
        ;
    }
  
    $irc->send_event(
        'irc_dcc_error',
        $id,
        $errstr,
        @{ $self->{dcc}->{$id} }{qw(
            nick type port file size done peeraddr
        )},
    );

    if (exists $self->{dcc}->{$id}->{wheel}) {
        delete $self->{wheelmap}->{$self->{dcc}->{$id}->{wheel}->ID};
    }
    delete $self->{dcc}->{$id};

    return;
}

# What happens when a DCC connection sits waiting for the other end to
# pick up the phone for too long.
sub _dcc_timeout {
    my ($kernel, $self, $id) = @_[KERNEL, OBJECT, ARG0];

    if (exists $self->{dcc}->{$id} && !$self->{dcc}->{$id}->{open}) {
        $kernel->yield(
            '_dcc_failed',
            'connection',
            0,
            'DCC connection timed out',
            $id,
        );
    }
    return;
}

# This event occurs when a DCC connection is established.
## no critic (InputOutput::RequireBriefOpen)
sub _dcc_up {
    my ($kernel, $self, $sock, $peeraddr, $id) =
        @_[KERNEL, OBJECT, ARG0, ARG1, ARG3];
    my $irc = $self->{irc};
    
    # Delete the listening socket and monitor the accepted socket
    # for incoming data
    delete $self->{dcc}->{$id}->{factory};
    $self->{dcc}->{$id}->{open} = 1;
    $self->{dcc}->{$id}->{peeraddr} = inet_ntoa($peeraddr);

    $self->{dcc}->{$id}->{wheel} = POE::Wheel::ReadWrite->new(
        Handle => $sock,
        Driver => ($self->{dcc}->{$id}->{type} eq 'GET'
            ? POE::Driver::SysRW->new( BlockSize => IN_BLOCKSIZE )
            : POE::Driver::SysRW->new()
        ),
        Filter => ($self->{dcc}->{$id}->{type} eq 'CHAT'
            ? POE::Filter::Line->new( Literal => "\012" )
            : POE::Filter::Stream->new()
        ),
        InputEvent => '_dcc_read',
        ErrorEvent => '_dcc_failed',
    );
    
    $self->{wheelmap}->{ $self->{dcc}->{$id}->{wheel}->ID } = $id;
    
    my $handle;
    if ($self->{dcc}->{$id}->{type} eq 'GET') {
        # check if we're resuming
        my $mode = -s $self->{dcc}->{$id}->{file} ? '>>' : '>';
        
        if ( !open $handle, $mode, $self->{dcc}->{$id}->{file} ) {
            $kernel->yield(_dcc_failed => 'open file', $! + 0, $!, $id);
            return;
        }
        
        binmode $handle;
        $self->{dcc}->{$id}->{fh} = $handle;
    }
    elsif ($self->{dcc}->{$id}->{type} eq 'SEND') {
        if (!open $handle, '<', $self->{dcc}->{$id}->{file}) {
            $kernel->yield(_dcc_failed => 'open file', $! + 0, $!, $id);
            return;
        }

        binmode $handle;
        # Send the first packet to get the ball rolling.
        read $handle, my $buffer, $self->{dcc}->{$id}->{blocksize};
        $self->{dcc}->{$id}->{wheel}->put($buffer);
        $self->{dcc}->{$id}->{fh} = $handle;
    }

    # Tell any listening sessions that the connection is up.
    $irc->send_event(
        'irc_dcc_start',
        $id,
        @{ $self->{dcc}->{$id} }{qw(
            nick type port file size peeraddr
        )},
    );
    
    return;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::DCC - A PoCo-IRC plugin providing support for
DCC transfers

=head1 SYNOPSIS

 # send a file
 my $file = '/home/user/secret.pdf';
 my $recipient = 'that_guy';
 $irc->yield(dcc => $recipient => SEND => $file);

 # receive a file
 sub irc_dcc_request {
     my ($user, $type, $port, $cookie, $file, $size, $addr) = @_[ARG0..$#_];
     return if $type ne 'SEND';

     my $irc = $_[SENDER]->get_heap();
     my $nick = (split /!/, $user)[0];

     print "$nick wants to send me '$file' ($size bytes) from $addr:$port\n");
     $irc->yield(dcc_accept => $cookie);
 }

=head1 DESCRIPTION

This plugin provides the IRC commands needed to make use of DCC. It is used
internally by L<POE::Component::IRC|POE::Component::IRC> so there's no
need to add it manually.

=head1 METHODS

=head2 C<new>

Takes no arguments.

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s C<plugin_add> method.

=head2 C<dccports>

Sets the TCP ports that can be used for DCC sends. Takes one argument,
an arrayref containing the port numbers.

=head2 C<nataddr>

Sets the public NAT address to be used for DCC sends.

=head2 C<dcc_info>

Takes one argument, a DCC connection id (see below). Returns a hash of
information about the connection. The keys are: B<'nick'>, B<'type'>,
B<'port'>, B<'file'>, B<'size'>, B<'done,'>, and B<'peeradr'>.

=head1 COMMANDS

The plugin responds to the following
L<POE::Component::IRC|POE::Component::IRC> commands.

=head2 C<dcc>

Send a DCC SEND or CHAT request to another person. Takes at least two
arguments: the nickname of the person to send the request to and the type
of DCC request (SEND or CHAT). For SEND requests, be sure to add a third
argument for the filename you want to send. Optionally, you can add a fourth
argument for the DCC transfer blocksize, but the default of 1024 should
usually be fine. The fifth (and optional) argument is the request timeout
value in seconds (default: 300).

Incidentally, you can send other weird nonstandard kinds of DCCs too;
just put something besides 'SEND' or 'CHAT' (say, 'FOO') in the type
field, and you'll get back C<irc_dcc_foo> events (with the same arguments as
L<C<irc_dcc_chat>|/"irc_dcc_chat">) when data arrives on its DCC connection.

If you are behind a firewall or Network Address Translation, you may want to
consult L<POE::Component::IRC|POE::Component::IRC>'s
L<C<connect>|POE::Component::IRC/"spawn"> for some parameters that are
useful with this command.

=head2 C<dcc_accept>

Accepts an incoming DCC connection from another host. First argument:
the magic cookie from an L<C<irc_dcc_request>|/"irc_dcc_request"> event.
In the case of a DCC GET, the second argument can optionally specify a
new name for the destination file of the DCC transfer, instead of using
the sender's name for it. (See the L<C<irc_dcc_request>|/"irc_dcc_request">
section below for more details.)

=head2 C<dcc_resume>

Resumes a DCC SEND file transfer. First argument: the magic cookie from an
L<C<irc_dcc_request>|/"irc_dcc_request"> event. An optional second argument
provides the name of the file to which you want to write.

=head2 C<dcc_chat>

Sends lines of data to the person on the other side of a DCC CHAT connection.
The first argument should be the wheel id of the connection which you got
from an L<C<irc_dcc_start>|/"irc_dcc_start"> event, followed by all the data
you wish to send (it'll be separated with newlines for you).

=head2 C<dcc_close>

Terminates a DCC SEND or GET connection prematurely, and causes DCC CHAT
connections to close gracefully. Takes one argument: the wheel id of the
connection which you got from an L<C<irc_dcc_start>|/"irc_dcc_start">
(or similar) event.

=head1 OUTPUT

=head2 C<irc_dcc_request>

B<Note:> This event is actually emitted by
L<POE::Filter::IRC::Compat|POE::Filter::IRC::Compat>, but documented here
to keep all the DCC documentation in one place. In case you were wondering.

You receive this event when another IRC client sends you a DCC
(e.g. SEND or CHAT) request out of the blue. You can examine the request
and decide whether or not to accept it (with L<C<dcc_accept>|/"dcc_accept">)
here. In the case of DCC SENDs, you can also request to resume the file with
L<C<dcc_resume>|/"dcc_resume">.

B<Note:> DCC doesn't provide a way to explicitly reject requests, so if you
don't intend to accept one, just ignore it or send a
L<NOTICE|POE::Component::IRC/"notice"> or L<PRIVMSG|POE::Component::IRC/"privmsg">
to the peer explaining why you're not going to accept.

=over 4

=item * C<ARG0>: the peer's nick!user@host

=item * C<ARG1>: the DCC type (e.g. 'CHAT' or 'SEND')

=item * C<ARG2>: the port which the peer is listening on

=item * C<ARG3>: this connection's "magic cookie"

=item * C<ARG4>: the file name (SEND only)

=item * C<ARG5>: the file size (SEND only)

=item * C<ARG6>: the IP address which the peer is listening on

=back

=head2 C<irc_dcc_start>

This event notifies you that a DCC connection has been successfully
established.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the peer's nickname

=item * C<ARG2>: the DCC type

=item * C<ARG3>: the port number

=item * C<ARG4>: the file name (SEND only)

=item * C<ARG5>: the file size (SEND only)

=item * C<ARG6>: the peer's IP address

=back

=head2 C<irc_dcc_chat>

Notifies you that one line of text has been received from the
client on the other end of a DCC CHAT connection.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the peer's nickname

=item * C<ARG2>: the port number

=item * C<ARG3>: the text they sent

=item * C<ARG4>: the peer's IP address

=back

=head2 C<irc_dcc_get>

Notifies you that another block of data has been successfully
transferred from the client on the other end of your DCC GET connection.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the peer's nickname

=item * C<ARG2>: the port number

=item * C<ARG3>: the file name

=item * C<ARG4>: the file size

=item * C<ARG5>: transferred file size

=item * C<ARG6>: the peer's IP address

=back

=head2 C<irc_dcc_send>

Notifies you that another block of data has been successfully
transferred from you to the client on the other end of a DCC SEND
connection.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the peer's nickname

=item * C<ARG2>: the port number

=item * C<ARG3>: the file name

=item * C<ARG4>: the file size

=item * C<ARG5>: transferred file size

=item * C<ARG6>: the peer's IP address

=back

=head2 C<irc_dcc_done>

You receive this event when a DCC connection terminates normally.
Abnormal terminations are reported by L<C<irc_dcc_error>|/"irc_dcc_error">.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the peer's nickname

=item * C<ARG2>: the DCC type

=item * C<ARG3>: the port number

=item * C<ARG4>: the filename (SEND only)

=item * C<ARG5>: file size (SEND only)

=item * C<ARG6>: transferred file size (SEND only)

=item * C<ARG7>: the peer's IP address

=back

=head2 C<irc_dcc_error>

You get this event whenever a DCC connection or connection attempt
terminates unexpectedly or suffers some fatal error. Some of the
following values might be undefined depending the stage at which
the connection/attempt failed.

=over 4

=item * C<ARG0>: the connection's wheel id

=item * C<ARG1>: the error string

=item * C<ARG2>: the peer's nickname

=item * C<ARG3>: the DCC type

=item * C<ARG4>: the port number

=item * C<ARG5>: the file name

=item * C<ARG6>: file size in bytes

=item * C<ARG7>: transferred file size in bytes

=item * C<ARG8>: the peer's IP address

=back

=head1 AUTHOR

Dennis 'C<fimmtiu>' Taylor and Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
