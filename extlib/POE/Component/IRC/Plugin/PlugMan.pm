package POE::Component::IRC::Plugin::PlugMan;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( :ALL );

our $VERSION = '5.76';

BEGIN { 
    # Turn on the debugger's symbol source tracing
    $^P |= 0x10;

    # Work around bug in pre-5.8.7 perl where turning on $^P
    # causes caller() to be confused about eval {}'s in the stack.
    # (See http://rt.perl.org/rt3/Ticket/Display.html?id=35059 for more info.)
    eval 'sub DB::sub' if $] < 5.008007;
}

sub new {
    my ($package, %args) = @_;
    $args{ lc $_ } = delete $args{ $_ } for keys %args;
    return bless \%args, $package;
}

##########################
# Plugin related methods #
##########################

sub PCI_register {
    my ($self, $irc) = @_;

    if ( !$irc->isa('POE::Component::IRC::State') ) {
        die __PACKAGE__ . ' requires PoCo::IRC::State or a subclass thereof';
    }

    $self->{irc} = $irc;
    $irc->plugin_register( $self, 'SERVER', qw(public msg) );
    
    $self->{commands} = {
        PLUGIN_ADD => sub {
            my ($self, $method, $recipient, @cmd) = @_;
            my $msg = $self->load(@cmd) ? 'Done.' : 'Nope';
            $self->{irc}->yield($method => $recipient => $msg);
        },
        PLUGIN_DEL => sub {
            my ($self, $method, $recipient, @cmd) = @_;
            my $msg = $self->unload(@cmd) ? 'Done.' : 'Nope';
            $self->{irc}->yield($method => $recipient => $msg);
        },
        PLUGIN_RELOAD => sub {
            my ($self, $method, $recipient, @cmd) = @_;
            my $msg = $self->reload(@cmd) ? 'Done.' : 'Nope';
            $self->{irc}->yield($method => $recipient => $msg);
        },
        PLUGIN_LIST => sub {
            my ($self, $method, $recipient, @cmd) = @_;
            my @aliases = keys %{ $self->{irc}->plugin_list() };
            my $msg = @aliases
                ? 'Plugins [ ' . join(', ', @aliases ) . ' ]'
                : 'No plugins loaded.';
            $self->{irc}->yield($method => $recipient => $msg);
        },
        PLUGIN_LOADED => sub {
            my ($self, $method, $recipient, @cmd) = @_;
            my @aliases = $self->loaded();
            my $msg = @aliases
                ? 'Managed Plugins [ ' . join(', ', @aliases ) . ' ]'
                : 'No managed plugins loaded.';
            $self->{irc}->yield($method => $recipient => $msg);
        },
    };

    return 1;
}

sub PCI_unregister {
    my ($self, $irc) = @_;
    delete $self->{irc};
    return 1;
}

sub S_public {
    my ($self, $irc) = splice @_, 0 , 2;
    my $nick = parse_user( ${ $_[0] } );
    my $channel = ${ $_[1] }->[0];
    my $what = ${ $_[2] };
    my $me = $irc->nick_name();

    my ($command) = $what =~ m/^\s*\Q$me\E[\:\,\;\.]?\s*(.*)$/i;
    return PCI_EAT_NONE if !$command || !$self->_bot_owner($nick);

    my (@cmd) = split(/ +/, $command);
    my $cmd = uc (shift @cmd);
    
    if (defined $self->{commands}->{$cmd}) {
        $self->{command}->{$cmd}->($self, 'privmsg', $channel, @cmd);
    }
    
    return PCI_EAT_NONE;
}

sub S_msg {
    my ($self, $irc) = splice @_, 0 , 2;
    my $nick = parse_user( ${ $_[0] } );
    my $channel = ${ $_[1] }->[0];
    my $command = ${ $_[2] };
    my (@cmd) = split(/ +/,$command);
    my $cmd = uc (shift @cmd);
    
    return PCI_EAT_NONE if !$self->_bot_owner($nick);
    
    if (defined $self->{commands}->{$cmd}) {
        $self->{command}->{$cmd}->($self, 'notice', $nick, @cmd);
    }

    return PCI_EAT_NONE;
}

#########################
# Trust related methods #
#########################

sub _bot_owner {
    my ($self, $nick) = @_;
    $nick = $self->{irc}->nick_long_form($nick) if $nick !~ /!/;
    return 1 if matches_mask( $self->{botowner}, $nick );
    return;
}

###############################
# Plugin manipulation methods #
###############################

sub load {
    my ($self, $desc, $plugin) = splice @_, 0, 3;
    return if !$desc || !$plugin;
    
    my $object;
    my $module = ref $plugin || $plugin;
    if (! ref $plugin){        
        $module .= '.pm' if $module !~ /\.pm$/;
        $module =~ s/::/\//g;

        eval "require $plugin";
        if ($@) {
            delete $INC{$module};
            $self->_unload_subs($plugin);
            die "$@\n";
        }

        $object = $plugin->new( @_ );
        return if !$object;
    } else {
        $object = $plugin;
        $plugin = ref $object;
    }
    
    my $args = [ @_ ];
    $self->{plugins}->{ $desc }->{module} = $module;
    $self->{plugins}->{ $desc }->{plugin} = $plugin;

    my $return = $self->{irc}->plugin_add( $desc, $object );
    if ( $return ) {
        # Stash away arguments for use later by _reload.
        $self->{plugins}->{ $desc }->{args} = $args;
    }
    else {
        # Cleanup
        delete $self->{plugins}->{ $desc };
    }
    
    return $return;
}

sub unload {
    my ($self, $desc) = splice @_, 0, 2;
    return if !$desc;

    my $plugin = $self->{irc}->plugin_del( $desc );
    return if !$plugin;
    my $module = $self->{plugins}->{ $desc }->{module};
    my $file = $self->{plugins}->{ $desc }->{plugin};
    delete $INC{$module};
    delete $self->{plugins}->{ $desc };
    $self->_unload_subs($file);
    return 1;
}

sub _unload_subs {
    my $self = shift;
    my $file = shift;

    for my $sym ( grep { index( $_, "$file:" ) == 0 } keys %DB::sub ) {
        eval { undef &$sym };
        warn "$sym: $@\n" if $@;
        delete $DB::sub{$sym};
    }

    return $self;
}

sub reload {
    my ($self, $desc) = splice @_, 0, 2;
    return if !defined $desc;

    my $plugin_state = $self->{plugins}->{ $desc };
    return if !$plugin_state;
    warn "Unloading plugin $desc\n" if $self->{debug};
    return if !$self->unload( $desc );

    warn "Loading plugin $desc " . $plugin_state->{plugin} . ' [ ' . join(', ',@{ $plugin_state->{args} }) . " ]\n" if $self->{debug};
    return if !$self->load( $desc, $plugin_state->{plugin}, @{ $plugin_state->{args} } );
    return 1;
}

sub loaded {
    my $self = shift;
    return keys %{ $self->{plugins} };
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::PlugMan - A PoCo-IRC plugin that provides plugin
management services. 

=head1 SYNOPSIS

 use strict;
 use warnings;
 use POE qw(Component::IRC::State);
 use POE::Component::IRC::Plugin::PlugMan;

 my $botowner = 'somebody!*@somehost.com';
 my $irc = POE::Component::IRC::State->spawn();

 POE::Session->create( 
     package_states => [ 
         main => [ qw(_start irc_plugin_add) ],
     ],
 );

 sub _start {
     $irc->yield( register => 'all' );
     $irc->plugin_add( 'PlugMan' => POE::Component::IRC::Plugin::PlugMan->new( botowner => $botowner ) );
     return;
 }

 sub irc_plugin_add {
     my ($desc, $plugin) = @_[ARG0, ARG1];
     
     if ($desc eq 'PlugMan') {
         $plugin->load( 'Connector', 'POE::Component::IRC::Plugin::Connector' );
     }
     return;
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::PlugMan is a POE::Component::IRC plugin management
plugin. It provides support for 'on-the-fly' loading, reloading and unloading
of plugin modules, via object methods that you can incorporate into your own
code and a handy IRC interface.

=head1 METHODS

=head2 C<new>

Takes two optional arguments:

'botowner', an IRC mask to match against for people issuing commands via the
IRC interface;
 
'debug', set to a true value to see when stuff goes wrong;

Not setting a 'botowner' effectively disables the IRC interface. 

If 'botowner' is specified the plugin checks that it is being loaded into a
L<POE::Component::IRC::State> or sub-class and will fail to load otherwise.

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head2 C<load>

Loads a managed plugin.

Takes two mandatory arguments, a plugin descriptor and a plugin package name.
Any other arguments are used as options to the loaded plugin constructor.

 $plugin->load( 'Connector', 'POE::Component::IRC::Plugin::Connector', delay, 120 );

Returns true or false depending on whether the load was successfully or not.

=head2 C<unload>

Unloads a managed plugin.

Takes one mandatory argument, a plugin descriptor.

 $plugin->unload( 'Connector' );

Returns true or false depending on whether the unload was successfully or not.

=head2 C<reload>

Unloads and loads a managed plugin, with applicable plugin options.

Takes one mandatory argument, a plugin descriptor.

 $plugin->reload( 'Connector' );

=head2 C<loaded>

Takes no arguments.

 $plugin->loaded();

Returns a list of descriptors of managed plugins.

=head1 INPUT

An IRC interface is enabled by specifying a "botowner" mask to new(). Commands
may be either invoked via a PRIVMSG directly to your bot or in a channel by
prefixing the command with the nickname of your bot. One caveat, the parsing
of the irc command is very rudimentary ( it merely splits the line on \s+ ). 

=head2 C<plugin_add>

Takes the same arguments as load().

=head2 C<plugin_del>

Takes the same arguments as unload().

=head2 C<plugin_reload>

Takes the same arguments as reload().

=head2 C<plugin_loaded>

Returns a list of descriptors of managed plugins.

=head2 C<plugin_list>

Returns a list of descriptors of *all* plugins loaded into the current PoCo-IRC
component.

=head1 AUTHOR

Chris 'BinGOs' Williams

=head1 SEE ALSO

L<POE::Component::IRC::State|POE::Component::IRC::State>

L<POE::Component::IRC::Plugin|POE::Component::IRC::Plugin>

=cut
