package HTTP::Engine::Interface::FCGI;
use HTTP::Engine::Interface
    builder => 'CGI',
    writer  => {
        response_line => 0,
        'write' => sub {
            my ($self, $buffer) = @_;
            *STDOUT->syswrite($buffer);
        },
    }
;
# XXX: We can't use Engine's write() method because syswrite
# appears to return bogus values instead of the number of bytes
# written: http://www.fastcgi.com/om_archive/mail-archive/0128.html

# FastCGI does not stream data properly if using 'print $handle',
# but a syswrite appears to work properly.

use constant RUNNING_IN_HELL => $^O eq 'MSWin32';
use FCGI;

has leave_umask => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has keep_stderr => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has nointr => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has detach => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has manager => (
    is      => 'ro',
    isa     => 'Str',
    default => "FCGI::ProcManager",
);

has nproc => (
    is      => 'ro',
    isa     => 'Int',
    default => 1,
);

has pidfile => (
    is      => 'ro',
    isa     => 'Str',
);

has listen => (
    is  => 'ro',
    isa => 'Str',
);

sub run {
    my ( $self, ) = @_;

    my $sock = 0;
    if ($self->listen) {
        my $old_umask = umask;
        unless ( $self->leave_umask ) {
            umask(0);
        }
        $sock = FCGI::OpenSocket( $self->listen, 100 )
          or die "failed to open FastCGI socket; $!";
        unless ( $self->leave_umask ) {
            umask($old_umask);
        }
    }
    elsif ( !RUNNING_IN_HELL ) {
        -S STDIN
          or die "STDIN is not a socket; specify a listen location";
    }

    my %env;
    my $error = \*STDERR;    # send STDERR to the web server
    $error = \*STDOUT                # send STDERR to stdout (a logfile)
      if $self->keep_stderr;         # (if asked to)

    my $request =
      FCGI::Request( \*STDIN, \*STDOUT, $error, \%env, $sock,
        ( $self->nointr ? 0 : &FCGI::FAIL_ACCEPT_ON_INTR ),
      );

    my $proc_manager;

    if ($self->listen) {
        $self->daemon_fork() if $self->detach;

        if ( $self->manager ) {
            Any::Moose::load_class($self->manager);
            $proc_manager = $self->manager->new(
                {
                    n_processes => $self->nproc,
                    pid_fname   => $self->pidfile,
                }
            );

            # detach *before* the ProcManager inits
            $self->daemon_detach() if $self->detach;

            $proc_manager->pm_manage();
        }
        elsif ( $self->detach ) {
            $self->daemon_detach();
        }
    }

    while ( $request->Accept >= 0 ) {
        $proc_manager && $proc_manager->pm_pre_dispatch();

        # If we're running under Lighttpd, swap PATH_INFO and SCRIPT_NAME
        # http://lists.rawmode.org/pipermail/catalyst/2006-June/008361.html
        # Thanks to Mark Blythe for this fix
        if ( $env{SERVER_SOFTWARE} && $env{SERVER_SOFTWARE} =~ /lighttpd/ ) {
            $env{PATH_INFO} ||= delete $env{SCRIPT_NAME};
        }

        $self->handle_request(
            _connection => {
                input_handle  => *STDIN,
                output_handle => *STDOUT,
                env           => \%env,
            },
        );

        $proc_manager && $proc_manager->pm_post_dispatch();
    }
}

sub daemon_fork {
    require POSIX;
    fork && exit;
}

sub daemon_detach {
    my $self = shift;
    print "FastCGI daemon started (pid $$)\n";
    open STDIN,  "+</dev/null" or die $!; ## no critic
    open STDOUT, ">&STDIN"     or die $!;
    open STDERR, ">&STDIN"     or die $!;
    POSIX::setsid();
}

__INTERFACE__

__END__

=for stopwords nointr pidfile nproc

=head1 NAME

HTTP::Engine::Interface::FCGI - FastCGI interface for HTTP::Engine

=head1 ATTRIBUTES

=over 4

=item leave_umask

=item keep_stderr

=item nointr

=item detach

=item manager

=item nproc

=item pidfile

=item listen

=back

=head1 AUTHORS

Tokuhiro Matsuno

=head1 THANKS TO

many codes copied from L<Catalyst::Engine::FastCGI>. thanks authors of C::E::FastCGI!

