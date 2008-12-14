package POE::Component::IRC::Plugin::Proxy;

use strict;
use warnings;
use Socket;
use POE qw(Wheel::SocketFactory Wheel::ReadWrite Filter::IRCD 
           Filter::Line Filter::Stackable);
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( :ALL );

our $VERSION = '5.86';

sub new {
    my ($package, %args) = @_;
    $args{ lc $_ } = delete $args{ $_ } for keys %args;
    return bless \%args, $package;
}

sub PCI_register {
    my ($self, $irc) = splice @_, 0, 2;

    $self->{raw_events} = $irc->raw_events();
    $irc->raw_events( '1' );
    $self->{irc} = $irc;
    $irc->plugin_register( $self, 'SERVER', qw(all) );

    $self->{SESSION_ID} = POE::Session->create(
        object_states => [
            $self => [ qw(_client_error _client_flush _client_input _listener_accept _listener_failed _start _shutdown _spawn_listener) ],
        ],
    )->ID();

    return 1;
}

sub PCI_unregister {
    my ($self, $irc) = splice @_, 0, 2;
    $irc->raw_events( $self->{raw_events} );
    $poe_kernel->post( $self->{SESSION_ID} => '_shutdown' => delete $self->{irc} );
    $poe_kernel->refcount_decrement( $self->{SESSION_ID}, __PACKAGE__ );
    return 1;
}

sub S_connected {
    my ($self, $irc) = splice @_, 0, 2;
    delete $self->{iamthis};
    $self->{stashed} = 0;
    $self->{stash} = [ ];
    return PCI_EAT_NONE;
}

sub S_001 {
    my ($self, $irc) = splice @_, 0, 2;
    $poe_kernel->post( $self->{SESSION_ID} => '_shutdown' );
    $irc->yield( 'privmsg' => $irc->nick_name() => "Who am I?" );
    return PCI_EAT_NONE;
}

sub S_msg {
    my ($self ,$irc) = splice @_, 0, 2;
    my ($who, $userhost) = split /!/, ${ $_[0] };

    return PCI_EAT_NONE if $who ne $irc->nick_name() || $self->{iamthis};
    $self->{iamthis} = $userhost;
    $poe_kernel->post( $self->{SESSION_ID} => '_spawn_listener' );
    return PCI_EAT_ALL;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    my $joiner = ( split /!/, ${ $_[0] } )[0];
    my $channel = ${ $_[1] };

    return PCI_EAT_NONE if $joiner ne $irc->nick_name();
    delete $self->{current_channels}->{ u_irc $channel };
    $self->{current_channels}->{ u_irc $channel } = $channel;
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    my $partee = ( split /!/, ${ $_[0] } )[0];
    my $channel = u_irc ${ $_[1] };

    return PCI_EAT_NONE if $partee ne $irc->nick_name();
    delete $self->{current_channels}->{ $channel };
    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc) = splice @_, 0, 2;
    my $kicked = u_irc( ${ $_[2] } );
    my $channel = u_irc ${ $_[1] };

    return PCI_EAT_NONE if $kicked ne u_irc $irc->nick_name(); 
    delete $self->{current_channels}->{ $channel };
    return PCI_EAT_NONE;
}

sub S_disconnected {
    my ($self, $irc) = splice @_, 0, 2;
    $poe_kernel->post( $self->{SESSION_ID} => '_shutdown' );
    return PCI_EAT_NONE;
}

sub S_socketerr {
    my ($self, $irc) = splice @_, 0, 2;
    $poe_kernel->post( $self->{SESSION_ID} => '_shutdown' );
    return PCI_EAT_NONE;
}

sub S_error {
    my ($self, $irc) = splice @_, 0, 2;
    $poe_kernel->post( $self->{SESSION_ID} => '_shutdown' );
    return PCI_EAT_NONE;
}

sub S_raw {
    my ($self, $irc) = splice @_, 0, 2;
    my $line = ${ $_[0] };

    return PCI_EAT_NONE if !defined $line;
    return PCI_EAT_ALL if $line =~ /^PING\s*/;
    
    for my $wheel_id ( keys %{ $self->{wheels} } ) {
        $self->_send_to_client( $wheel_id, $line );
    }
    $self->_stash_line( $line );
    return PCI_EAT_ALL;
}

sub _stash_line {
    my ($self, $line) = splice @_, 0, 2;
    return if !defined $line;
    return if $self->{stashed};
    
    my ($prefix, $numeric) = ( split / /, $line )[0..1];
    if ( $prefix eq 'NOTICE' ) {
        push @{ $self->{stash} }, $line;
        return;
    }
    
    $prefix =~ s/^://;
    if ( defined $self->{irc}->server_name and $numeric eq 'NOTICE' and $prefix eq $self->{irc}->server_name() ) {
        push @{ $self->{stash} }, $line;
        return;
    }

    return if !$numeric || $numeric =~ /^\d{3,3}$/;
    if ( $numeric eq '376' or $numeric eq '422' ) {
        push @{ $self->{stash} }, $line;
        $self->{stashed} = 1;
        return;
    }

    push @{ $self->{stash} }, $line;
    return;
}

sub _send_to_client {
    my ($self, $wheel_id, $line) = splice @_, 0, 3;
    return if !defined $self->{wheels}->{ $wheel_id }->{wheel};
    return if !$self->{wheels}->{ $wheel_id }->{reg};
    
    $self->{wheels}->{ $wheel_id }->{wheel}->put( $line );
    return 1;
}

sub _close_wheel {
    my ($self, $wheel_id) = splice @_, 0, 2;
    return if !defined $self->{wheels}->{ $wheel_id };

    delete $self->{wheels}->{ $wheel_id };
    $self->{irc}->send_event( 'irc_proxy_close' => $wheel_id );
    return;
}

sub _start {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->{SESSION_ID} = $_[SESSION]->ID();
    $kernel->refcount_increment( $self->{SESSION_ID}, __PACKAGE__ );
    $self->{irc_filter} = POE::Filter::IRCD->new();
    $self->{ircd_filter} = POE::Filter::Stackable->new( Filters => [
        POE::Filter::Line->new(),
        $self->{irc_filter}
    ]);
    
    if ( $self->{irc}->connected() ) {
        $kernel->yield( '_spawn_listener' );
    }
    return;
}

sub _spawn_listener {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->{listener} = POE::Wheel::SocketFactory->new(
        BindAddress  => $self->{bindaddress} || 'localhost',
        BindPort     => $self->{bindport} || 0,
        SuccessEvent => '_listener_accept',
        FailureEvent => '_listener_failed',
        Reuse        => 'yes',
    );
    
    if (!$self->{listener}) {
        my $irc = $self->{irc};
        $irc->plugin_del($self);
        return;
    }
    
    $self->{irc}->send_event( 'irc_proxy_up' => $self->{listener}->getsockname() );
    return;
}

sub _listener_accept {
    my ($kernel, $self, $socket, $peeradr, $peerport)
        = @_[KERNEL, OBJECT, ARG0 .. ARG2];

    my $wheel = POE::Wheel::ReadWrite->new(
        Handle       => $socket,
        InputFilter  => $self->{ircd_filter},
        OutputFilter => POE::Filter::Line->new(),
        InputEvent   => '_client_input',
        ErrorEvent   => '_client_error',
        FlushedEvent => '_client_flush',
    );

    if ( $wheel ) {
        my $wheel_id = $wheel->ID();
        $self->{wheels}->{ $wheel_id }->{wheel} = $wheel;
        $self->{wheels}->{ $wheel_id }->{port} = $peerport;
        $self->{wheels}->{ $wheel_id }->{peer} = inet_ntoa( $peeradr );
        $self->{wheels}->{ $wheel_id }->{start} = time();
        $self->{wheels}->{ $wheel_id }->{reg} = 0;
        $self->{wheels}->{ $wheel_id }->{register} = 0;
        $self->{irc}->send_event( 'irc_proxy_connect' => $wheel_id );
    }
    else {
        $self->{irc}->send_event( 'irc_proxy_rw_fail' => inet_ntoa( $peeradr ) => $peerport );
    }
    
    return;
}

sub _listener_failed {
    delete ( $_[OBJECT]->{listener} );
    return;
}

sub _client_flush {
    my ($kernel, $self, $wheel_id) = @_[KERNEL, OBJECT, ARG0];

    return if !defined ( $self->{wheels}->{ $wheel_id } ) or !$self->{wheels}->{ $wheel_id }->{quiting};
    $self->_close_wheel( $wheel_id );
    return;
}

# this code needs refactoring
## no critic
sub _client_input {
    my ($kernel, $self, $input, $wheel_id) = @_[KERNEL, OBJECT, ARG0, ARG1];

    SWITCH: {
        if ( $self->{wheels}->{ $wheel_id }->{quiting} ) {
            last SWITCH;
        }
        if ( $input->{command} eq 'QUIT' ) {
            $self->_close_wheel( $wheel_id );
            last SWITCH;
        }
        if ( $input->{command} eq 'PASS' and $self->{wheels}->{ $wheel_id }->{reg} < 2 ) {
            $self->{wheels}->{ $wheel_id }->{pass} = $input->{params}->[0];
        }
        if ( $input->{command} eq 'NICK' and $self->{wheels}->{ $wheel_id }->{reg} < 2 ) {
            $self->{wheels}->{ $wheel_id }->{nick} = $input->{params}->[0];
            $self->{wheels}->{ $wheel_id }->{register}++;
        }
        if ( $input->{command} eq 'USER' and $self->{wheels}->{ $wheel_id }->{reg} < 2 ) {
            $self->{wheels}->{ $wheel_id }->{user} = $input->{params}->[0];
            $self->{wheels}->{ $wheel_id }->{register}++;
        }
        if ( ( not $self->{wheels}->{ $wheel_id }->{reg} ) and $self->{wheels}->{ $wheel_id }->{register} >= 2 ) {
            my $password = delete $self->{wheels}->{ $wheel_id }->{pass};
            $self->{wheels}->{ $wheel_id }->{reg} = 1;
            if ( !$password || $password ne $self->{password} ) {
                $self->_send_to_client( $wheel_id => 'ERROR :Closing Link: * [' . ( $self->{wheels}->{ $wheel_id }->{user} || "unknown" ) . '@' . $self->{wheels}->{ $wheel_id }->{peer} . '] (Unauthorised connection)' );
                $self->{wheels}->{ $wheel_id }->{quiting}++;
                last SWITCH;
            }
            my $nickname = $self->{irc}->nick_name();
            my $fullnick = join('!', $nickname, $self->{iamthis} );
            if ( $nickname ne $self->{wheels}->{ $wheel_id }->{nick} ) {
                $self->_send_to_client( $wheel_id, $self->{wheels}->{ $wheel_id }->{nick} . " NICK :$nickname" );
            }
            for my $line ( @{ $self->{stash} } ) {
                $self->_send_to_client( $wheel_id, $line );
            }
            for my $channel ( $self->current_channels() ) {
                $self->_send_to_client( $wheel_id, ":$fullnick JOIN $channel" );
                $self->{irc}->yield( 'names' => $channel );
                $self->{irc}->yield( 'topic' => $channel );
            }
            $self->{irc}->send_event( 'irc_proxy_authed' => $wheel_id );
            last SWITCH;
        }
    
        if ( !$self->{wheels}->{ $wheel_id }->{reg} ) {
            last SWITCH;
        }
        if ( $input->{command} eq 'NICK' or $input->{command} eq 'USER' or $input->{command} eq 'PASS' ) {
            last SWITCH;
        }
        if ( $input->{command} eq 'PING' ) {
            $self->_send_to_client( $wheel_id, 'PONG ' . $input->{params}->[0] );
            last SWITCH;
        }
        if ( $input->{command} eq 'PONG' and $input->{params}->[0] =~ /^[0-9]+$/ ) {
            $self->{wheels}->{ $wheel_id }->{lag} = time() - $input->{params}->[0];
            last SWITCH;
        }
        $self->{irc}->yield( lc ( $input->{command} ) => @{ $input->{params} } );
    }

    return;
}

sub _client_error {
    my ($self, $wheel_id) = @_[OBJECT, ARG3];

    $self->_close_wheel( $wheel_id );
    return;
}

sub _shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    my $irc = $self->{irc} || $_[ARG0];

    delete $self->{current_channels};
    my $mysockaddr = $self->getsockname();
    delete $self->{listener};
    
    for my $wheel_id ( $self->list_wheels() ) {
        $self->_close_wheel( $wheel_id );
    }
    delete $self->{wheels};
    $irc->send_event( 'irc_proxy_down' => $mysockaddr );
    
    return;
}

sub getsockname {
    my $self = shift;
    return if !$self->{listener};
    return $self->{listener}->getsockname();
}

sub list_wheels {
    my $self = shift;
    return keys %{ $self->{wheels} };
}

sub wheel_info {
    my ($self, $wheel_id) = @_;
    return if !defined $self->{wheels}->{ $wheel_id };
    return $self->{wheels}->{ $wheel_id }->{start} if !wantarray();
    return map { $self->{wheels}->{ $wheel_id }->{$_} } qw(peer port start lag);
}

sub current_channels {
    my ($self) = @_;
    return if !defined $self->{current_channels} || !keys %{ $self->{current_channels} };
    return ( map { $self->{current_channels}->{ $_ } } keys %{ $self->{current_channels} } );
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::Proxy - A PoCo-IRC plugin that provides a
lightweight IRC proxy/bouncer for L<POE::Component::IRC|POE::Component::IRC>.

=head1 SYNOPSIS

 use strict;
 use warnings;
 use POE qw(Component::IRC Component::IRC::Plugin::Proxy Component::IRC::Connector);

 my $irc = POE::Component::IRC->spawn();

 POE::Session->create( 
     package_states => [ 
         main => [ qw(_start) ],
     ],
     heap => { irc => $irc },
 );

 $poe_kernel->run();

 sub _start {
     my ($kernel, $heap) = @_[KERNEL, HEAP];
     $heap->{irc}->yield( register => 'all' );
     $heap->{proxy} = POE::Component::IRC::Plugin::Proxy->new( bindport => 6969, password => "m00m00" );
     $heap->{irc}->plugin_add( 'Connector' => POE::Component::IRC::Connector->new() );
     $heap->{irc}->plugin_add( 'Proxy' => $heap->{proxy} );
     $heap->{irc}->yield ( connect => { Nick => 'testbot', Server => 'someserver.com' } );
     return;
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::Proxy is a L<POE::Component::IRC|POE::Component::IRC>
plugin that provides lightweight IRC proxy/bouncer server to your
L<POE::Component::IRC|POE::Component::IRC> bots. It enables multiple IRC
clients to be hidden behind a single IRC client-server connection.

Spawn a L<POE::Component::IRC|POE::Component::IRC> session and add in a
POE::Component::IRC::Plugin::Proxy plugin object, specifying a bindport and a
password the connecting IRC clients have to use. When the component is
connected to an IRC network a listening port is opened by the plugin for
multiple IRC clients to connect. 

Neat, huh? >;o)

=head1 METHODS

=head2 C<new>

Takes a number of arguments:

'password', the password to require from connecting clients;

'bindaddr', a local address to bind the listener to, default is 'localhost';

'bindport', what port to bind to, default is 0, ie. randomly allocated by OS;

Returns an object suitable for passing to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head2 C<current_channels>

Takes no arguments, returns a list of the channels that the component is
currently a member of.

=head2 C<getsockname>

Takes no arguments.  Accesses the listeners getsockname() method. See
L<POE::Wheel::SocketFactory|POE::Wheel::SocketFactory> for details of the
return value;

=head2 C<list_wheels>

Takes no arguments. Returns a list of wheel ids of the current connected clients.

=head2 C<wheel_info>

Takes one parameter, a wheel ID to query. Returns undef if an invalid wheel id
is passed. In a scalar context returns the time that the client connected in
unix time. In a list context returns a list consisting of the peer address,
port, tthe connect time and the lag in seconds for that connection.

=head1 OUTPUT

The plugin emits the following L<POE::Component::IRC|POE::Component::IRC>
events:

=head2 C<irc_proxy_up>

Emitted when the listener is successfully started. ARG0 is the result of the
listener getsockname().

=head2 C<irc_proxy_connect>

Emitted when a client connects to the listener. ARG0 is the wheel ID of the
client.

=head2 C<irc_proxy_rw_fail>

Emitted when the Wheel::ReadWrite fails on a connection. ARG0 is the wheel ID
of the client.

=head2 C<irc_proxy_authed>

Emitted when a connecting client successfully negotiates an IRC session with
the plugin. ARG0 is the wheel ID of the client.

=head2 C<irc_proxy_close>

Emitted when a connected client disconnects. ARG0 is the wheel ID of the client.

=head2 C<irc_proxy_down>

Emitted when the listener is successfully shutdown. ARG0 is the result of the
listener getsockname().

=head1 QUIRKS

Connecting IRC clients will not be able to change nickname. This is a feature.

=head1 AUTHOR

Chris 'BinGOs' Williams

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

=cut
