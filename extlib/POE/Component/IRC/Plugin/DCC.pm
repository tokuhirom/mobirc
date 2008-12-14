package POE::Component::IRC::Plugin::DCC;

use strict;
use warnings;
use File::Basename qw(fileparse);
use POE qw(Driver::SysRW Filter::Line Filter::Stream
           Wheel::ReadWrite Wheel::SocketFactory);
use POE::Component::IRC::Plugin qw(:ALL);
use Socket;

our $VERSION = '1.1';

use constant {
    BLOCKSIZE          => 1024,  # Send DCC data in 1k chunks
    INCOMING_BLOCKSIZE => 10240, # 10k per DCC socket read
    DCC_TIMEOUT        => 300,   # Five minutes for listening DCCs
};

sub new {
    my ($package, %self) = @_;
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

sub S_disconnected {
    my ($self) = $_;
    # clean up old cookies for any ignored RESUME requests 
    delete $self->{resuming};
    return PCI_EAT_NONE;
}

sub S_dcc_request {
    my ($self, $irc) = splice @_, 0, 2;
    my ($nick, $type, $port, $cookie, $file, $size) = map { ref =~ /REF|SCALAR/ && ${ $_ } } @_;

    if ($type eq 'ACCEPT' && $self->{resuming}->{"$port+$nick"}) {

        # the old cookie has the peer's address
        my $old_cookie = delete $self->{resuming}->{"$port+$nick"};
        $irc->yield(dcc_accept => $old_cookie);
    }
    elsif ($type eq 'RESUME') {
        for my $cookie (values %{ $self->{dcc} }) {
            next if $cookie->{nick} ne $nick;
            next if $cookie->{port} ne $port;
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
    my ($bindport, $factory, $port, $myaddr, $size);

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
                0,
                "Couldn't get ${file}'s size: $!",
                $nick,
                $type,
                0,
                $file,
            );
            return;
        }
    }
    
    my $localaddr = $irc->localaddr;
    if ($localaddr && $localaddr =~ tr/a-zA-Z.//) {
        $localaddr = inet_aton($localaddr);
    }

    if ($self->{dccports}) {
        $bindport = shift @{ $self->{dccports} };
        if (!defined $bindport) {
          warn "dcc: Can't allocate listen port for DCC $type\n";
          return;
        }
    }

    $factory = POE::Wheel::SocketFactory->new(
        BindAddress  => $localaddr || INADDR_ANY,
        BindPort     => $bindport,
        SuccessEvent => '_dcc_up',
        FailureEvent => '_dcc_failed',
        Reuse        => 'yes',
    );
    
    ($port, $myaddr) = unpack_sockaddr_in($factory->getsockname());
    $myaddr = inet_aton($self->{nataddr}) if $self->{nataddr};
  
    if (!defined $myaddr) {
        warn "dcc: Can't determine our IP address! ($!)\n";
        return;
    }
    $myaddr = unpack 'N', $myaddr;

    my $basename = fileparse($file);
    $basename = qq{"$basename"} if $basename =~ /[\s"]/;

    # Tell the other end that we're waiting for them to connect.
    $irc->yield(ctcp => $nick => "DCC $type $basename $myaddr $port" . ($size ? " $size" : ''));

    # Store the state for this connection.
    $self->{dcc}->{ $factory->ID } = {
        open       => undef,
        nick       => $nick,
        type       => $type,
        file       => $file,
        size       => $size,
        port       => $port,
        addr       => $myaddr,
        done       => 0,
        blocksize  => ($blocksize || BLOCKSIZE),
        listener   => 1,
        factory    => $factory,
        listenport => $bindport,
        clientaddr => $myaddr,
    };
    
    $kernel->alarm(
        '_dcc_timeout',
        time() + ($timeout || DCC_TIMEOUT),
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
        warn "dcc_chat: No DCC wheel for $id!\n";
        return;
    }
  
    if ($self->{dcc}->{$id}->{type} ne 'CHAT') {
        warn "dcc_chat: $id isn't a DCC CHAT connection!\n";
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

    if ($self->{dcc}->{$id}->{wheel}->get_driver_out_octets()) {
        $kernel->delay_set(
            '_event_dcc_close',
            2,
            \$id,
        );
        return;
    }

    $irc->send_event(
        'irc_dcc_done',
        $id,
        @{ $self->{dcc}->{$id} }{qw(
            nick type port file size
            done listenport clientaddr
        )},
    );

    # Reclaim our port if necessary.
    if ($self->{dcc}->{$id}->{listener} && $self->{dccports}
        && $self->{dcc}->{$id}->{listenport}) {
        push ( @{ $self->{dccports} }, $self->{dcc}->{$id}->{listenport} );
    }

    if (exists $self->{dcc}->{$id}->{wheel}) {
        delete $self->{wheelmap}->{$self->{dcc}->{$id}->{wheel}->ID};
        delete $self->{dcc}->{$id}->{wheel};
    }

    delete $self->{dcc}->{$id};
    return;
}

# bboett - first step - the user asks for a resume:
# tries to resume a previous dcc transfer. See '_dcc_up' for
# the rest of the logic for this.
sub _event_dcc_resume {
    my ($self, $cookie, $myfile) = @_[OBJECT, ARG0, ARG1];
    my $irc = $self->{irc};

    my $sender_file = $cookie->{file};
    $cookie->{file} = $myfile if defined $myfile;
    my $size = -s $cookie->{file};
    my $fraction = $size % INCOMING_BLOCKSIZE;
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
                nick port file size
                done listenport clientaddr
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
                nick port file size done
                listenport clientaddr
            )},
        );

        # Are we done yet?
        if ($self->{dcc}->{$id}->{done} >= $self->{dcc}->{$id}->{size}) {
            # Reclaim our port if necessary.
            if ( $self->{dcc}->{$id}->{listener} && $self->{dccports}
                && $self->{dcc}->{$id}->{listenport} ) {
                push @{ $self->{dccports} },
                    $self->{dcc}->{$id}->{listenport};
            }

            $irc->send_event(
                'irc_dcc_done',
                $id,
                @{ $self->{dcc}->{$id} }{qw(
                    nick type port file size
                    done listenport clientaddr
                )},
            );
            delete $self->{wheelmap}->{ $self->{dcc}->{$id}->{wheel}->ID };
            delete $self->{dcc}->{$id}->{wheel};
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
    if ( $self->{dcc}->{$id}->{listener} && $self->{dccports}
        && $self->{dcc}->{$id}->{listenport} ) {
        push ( @{ $self->{dccports} }, $self->{dcc}->{$id}->{listenport} );
    }

    DCC: {
        last DCC if $errnum != 0;
    
        # Did the peer of a DCC GET connection close the socket after the file
        # transfer finished? If so, it's not really an error.
        if ($self->{dcc}->{$id}->{type} eq 'GET') {
            if ($self->{dcc}->{$id}->{done} < $self->{dcc}->{$id}->{size}) {
                last DCC;
            }
      
            $irc->send_event(
                'irc_dcc_done',
                $id,
                @{ $self->{dcc}->{$id} }{qw(
                    nick type port file size
                    done listenport clientaddr
                )},
            );

            if ( $self->{dcc}->{$id}->{wheel} ) {
                delete $self->{wheelmap}->{ $self->{dcc}->{$id}->{wheel}->ID };
            }
            delete $self->{dcc}->{$id};
        }
        elsif ($self->{dcc}->{$id}->{type} eq 'CHAT') {
            $irc->send_event(
                'irc_dcc_done',
                $id,
                @{ $self->{dcc}->{$id} }{qw(
                    nick type port done
                    listenport clientaddr
                )}
            );
      
            if ($self->{dcc}->{$id}->{wheel}) {
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
            nick type port file size
            done listenport clientaddr
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
sub _dcc_up {
    my ($kernel, $self, $sock, $addr, $port, $id) =
        @_[KERNEL, OBJECT, ARG0 .. ARG3];
    my $irc = $self->{irc};
    
    # Monitor the new socket for incoming data
    # and delete the listening socket.
    delete $self->{dcc}->{$id}->{factory};
    $self->{dcc}->{$id}->{addr} = $addr;
    $self->{dcc}->{$id}->{clientaddr} = inet_ntoa($addr);
    $self->{dcc}->{$id}->{port} = $port;
    $self->{dcc}->{$id}->{open} = 1;

    $self->{dcc}->{$id}->{wheel} = POE::Wheel::ReadWrite->new(
        Handle => $sock,
        Driver => ($self->{dcc}->{$id}->{type} eq 'GET'
            ? POE::Driver::SysRW->new( BlockSize => INCOMING_BLOCKSIZE )
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
        @{ $self->{dcc}->{$id} }{qw(nick type port)},
        ($self->{dcc}->{$id}->{'type'} =~ /^(SEND|GET)$/
            ? (@{ $self->{dcc}->{$id} }{qw(file size)})
            : ()
        ),
        @{ $self->{dcc}->{$id} }{qw(listenport clientaddr)},
    );
    
    return;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::DCC - a PoCo-IRC plugin providing DCC support

=head1 SYNOPSIS

 # send a file
 my $file = '/home/user/secret.pdf';
 my $recipient = 'that_guy';
 $irc->dcc($recipient => SEND => $file);

 # receive a file
 sub irc_dcc_request {
     my ($user, $type, $port, $cookie, $file, $size) = @_[ARG0..$#_];
     return if $type ne 'SEND';

     my $irc = $_[SENDER]->get_heap();
     my $nick = (split /!/, $user)[0];
     print "$nick wants to send me '$file' (size: $size) on port $port\n");
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
L<POE::Component::IRC|POE::Component::IRC>'s C<plugin_add()> method.

=head2 C<dccports>

Sets the TCP ports that can be used for DCC sends. Takes one argument,
an arrayref containing the port numbers.

=head2 C<nataddr>

Sets the public NAT address to be used for DCC sends.

=head1 COMMANDS

The plugin responds to the following
L<POE::Component::IRC|POE::Component::IRC> commands.

=head2 C<dcc>

Send a DCC SEND or CHAT request to another person. Takes at least two
arguments: the nick!user@host of the person to send the request to and the
type of DCC request (SEND or CHAT). For SEND requests, be sure to add
a third argument for the filename you want to send. Optionally, you
can add a fourth argument for the DCC transfer blocksize, but the
default of 1024 should usually be fine.

Incidentally, you can send other weird nonstandard kinds of DCCs too;
just put something besides 'SEND' or 'CHAT' (say, 'FOO') in the type
field, and you'll get back C<irc_dcc_*> events when activity happens
on its DCC connection.

If you are behind a firewall or Network Address Translation, you may want to
consult L<POE::Component::IRC|POE::Component::IRC>'s
L<C<connect>|POE::Component::IRC/"connect"> for some parameters that are
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
Takes any number of arguments: the magic cookie from an
L<C<irc_dcc_start>|/"irc_dcc_start"> event, followed by the data you wish to
send. (It'll be separated by newlines for you.)

=head2 C<dcc_close>

Terminates a DCC SEND or GET connection prematurely, and causes DCC CHAT
connections to close gracefully. Takes one argument: the magic cookie
from an L<C<irc_dcc_start>|/"irc_dcc_start"> or
L<C<irc_dcc_request>|/"irc_dcc_request"> event.

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

=over

=item ARG0: the peer's nickname

=item ARG1: the port which the peer is listening on

=item ARG2: the DCC type

=item ARG3: this connection's "magic cookie"

=item ARG4: the file name

=item ARG5: the file size (SEND only)

=back

=head2 C<irc_dcc_chat>

Notifies you that one line of text has been received from the
client on the other end of a DCC CHAT connection.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the peer's nickname

=item ARG2: the port number

=item ARG3: the text they sent

=back

=head2 C<irc_dcc_done>

You receive this event when a DCC connection terminates normally.
Abnormal terminations are reported by L<C<irc_dcc_error>|/"irc_dcc_error">.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the peer's nickname

=item ARG2: the DCC type

=item ARG3: the port number

=item ARG4: the filename

=item ARG5: file size (SEND/GET only)

=item ARG6: transferred file size (SEND/GET only, should be same as ARG5)

=back

=head2 C<irc_dcc_failed>

You get this event when a DCC connection fails for some reason.

=over

=item ARG0: the operation that failed

=item ARG1: the error number

=item ARG2: the error string

=item ARG3: this connection's "magic cookie"

=back

=head2 C<irc_dcc_error>

You get this event whenever a DCC connection or connection attempt
terminates unexpectedly or suffers some fatal error.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the error string

=item ARG2: the peer's nickname

=item ARG3: the DCC type

=item ARG4: the port number

=item ARG5: the file name

=item ARG6: expected file size

=item ARG7: tranferred file size

=back

=head2 C<irc_dcc_get>

Notifies you that another block of data has been successfully
transferred from the client on the other end of your DCC GET connection.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the peer's nickname

=item ARG2: the port number

=item ARG3: the file name

=item ARG4: the file size

=item ARG5: transferred file size

=back

=head2 C<irc_dcc_send>

Notifies you that another block of data has been successfully
transferred from you to the client on the other end of a DCC SEND
connection.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the peer's nickname

=item ARG2: the port number

=item ARG3: the file name

=item ARG4: the file size

=item ARG5: transferred file size

=back

=head2 C<irc_dcc_start>

This event notifies you that a DCC connection has been successfully
established.

=over

=item ARG0: this connection's "magic cookie"

=item ARG1: the peer's nickname

=item ARG2: the DCC type

=item ARG3: the port number

=item ARG4: the file name (SEND/GET only)

=item ARG5: the file size (SEND/GET only)

=back

=head1 AUTHOR

Dennis 'C<fimmtiu>' Taylor, et al.

=cut
