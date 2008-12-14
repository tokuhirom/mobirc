package POE::Component::IRC::Plugin::CycleEmpty;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( parse_user u_irc );

our $VERSION = '1.1';

sub new {
    my ($package, %self) = @_;
    return bless \%self, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    
    if (!$irc->isa('POE::Component::IRC::State')) {
        die __PACKAGE__ . " requires PoCo::IRC::State or a subclass thereof";
    }
    
    $self->{cycling} = { };
    $self->{irc} = $irc;
    $irc->plugin_register($self, 'SERVER', qw(join kick part quit));
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan = ${ $_[1] };
    delete $self->{cycling}->{$chan};
    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan = ${ $_[1] };
    my $victim = ${ $_[2] };
    $self->_cycle($chan) if $victim ne $irc->nick_name();
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    my $parter = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    $self->_cycle($chan) if $parter ne $irc->nick_name();
    return PCI_EAT_NONE;
}

sub S_quit {
    my ($self, $irc) = splice @_, 0, 2;
    my $quitter = parse_user(${ $_[0] });
    my $channels = @{ $_[2] }[0];
    if ($quitter ne $irc->nick_name()) {
        for my $chan (@{ $channels }) {
            $self->_cycle($chan);
        }
    }
    return PCI_EAT_NONE;
}

sub _cycle {
    my ($self, $chan) = @_;
    my $irc = $self->{irc};
    if ($irc->channel_list($chan) == 1) {
        if (!$irc->is_channel_operator($chan, $irc->nick_name)) {
            $self->{cycling}->{ u_irc($chan) } = 1;
            my $topic = $irc->channel_topic($chan);
            $irc->yield(part => $chan);
            $irc->yield(join => $chan => $irc->channel_key($chan));
            $irc->yield(topic => $chan => $topic->{Value}) if defined $topic->{Value};
            $irc->yield(mode => $chan => '+k ' . $irc->channel_key($chan)) if defined $irc->channel_key($chan);
        }
    }
    return;
}

sub is_cycling {
    my ($self, $value) = @_;
    return 1 if $self->{cycling}->{ u_irc($value) };
    return;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::CycleEmpty - A PoCo-IRC plugin which cycles
(parts and rejoins) channels if they become empty and opless, in order
to gain ops.

=head1 SYNOPSIS

 use POE::Component::IRC::Plugin::CycleEmpty;

 $irc->plugin_add( 'CycleEmpty', POE::Component::IRC::Plugin::CycleEmpty->new();

=head1 DESCRIPTION

POE::Component::IRC::Plugin::CycleEmpty is a L<POE::Component::IRC|POE::Component::IRC>
plugin. When someone quits, gets kicked, or parts a channel, the plugin will
cycle the channel if the IRC component is alone on that channel and is not
a channel operator. If there was a topic or a key set on the channel, they
will be restored upon rejoining. This can be useful on small channels if the
IRC network does not have ChanServ or IRCNet's +R channel mode.

This plugin requires the IRC component to be
L<POE::Component::IRC::State|POE::Component::IRC::State> or a subclass thereof.

=head1 METHODS

=head2 C<new>

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head2 C<is_cycling>

One argument:

A channel name

Returns 1 if the plugin is currently cycling that channel, 0 otherwise.
Useful if need to ignore the fact that the Component just parted the channel
in question.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
