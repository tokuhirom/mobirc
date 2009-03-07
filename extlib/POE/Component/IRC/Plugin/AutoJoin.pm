package POE::Component::IRC::Plugin::AutoJoin;

use strict;
use warnings;
use Carp;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( parse_user );

our $VERSION = '6.02';

sub new {
    my ($package) = shift;
    croak "$package requires an even number of arguments" if @_ & 1;
    my %self = @_;
    return bless \%self, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    
    if (!$irc->isa('POE::Component::IRC::State')) {
        die  __PACKAGE__ . ' requires PoCo::IRC::State or a subclass thereof';
    }
    
    if (!$self->{Channels}) {
        for my $chan (keys %{ $irc->channels() }) {
            $self->{Channels}->{$chan} = $irc->channel_key($chan);
        }
    }
    elsif (ref $self->{Channels} eq 'ARRAY') {
        my $channels;
        $channels->{$_} = '' for @{ $self->{Channels} };
        $self->{Channels} = $channels;
    }

    $self->{Rejoin_delay} = 5 if !defined $self->{Rejoin_delay};
    $irc->plugin_register($self, 'SERVER', qw(004 474 chan_mode join kick part));
    return 1;
}

sub PCI_unregister {
    return 1;
}

# we join channels after 004 rather than 001 so that the NickServID plugin
# can check the server version and identify before we join channels
sub S_004 {
    my ($self, $irc) = splice @_, 0, 2;
    
    while (my ($chan, $key) = each %{ $self->{Channels} }) {
        $irc->yield(join => $chan => $key);
    }
    return PCI_EAT_NONE;
}

# ERR_BANNEDFROMCHAN
sub S_474 {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan = ${ $_[2] }->[0];
    return if !$self->{Retry_when_banned};

    my $pass = defined $self->{Channels}->{$chan} ? $self->{Channels}->{$chan} : '';
    $irc->delay([join => $chan => $pass ], $self->{Retry_when_banned});
    return PCI_EAT_NONE;
}

sub S_chan_mode {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan = ${ $_[1] };
    my $mode = ${ $_[2] };
    my $arg  = ${ $_[3] };

    $self->{Channels}->{$chan} = $arg if $mode eq '+k';
    $self->{Channels}->{$chan} = '' if $mode eq '-k';
    return PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    my $joiner = parse_user(${ $_[0] });
    my $chan   = ${ $_[1] };

    if ($joiner eq $irc->nick_name()) {
        $self->{Channels}->{$chan} = $irc->channel_key($chan);
    }
    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan   = ${ $_[1] };
    my $victim = ${ $_[2] };

    if ($victim eq $irc->nick_name()) {
        if ($self->{RejoinOnKick}) {
            $irc->delay([join => $chan => $self->{Channels}->{$chan}], $self->{Rejoin_delay});
        }
        delete $self->{Channels}->{$chan};
    }
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    my $parter = parse_user(${ $_[0] });
    my $chan   = ${ $_[1] };

    delete $self->{Channels}->{$chan} if $parter eq $irc->nick_name();
    return PCI_EAT_NONE;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::AutoJoin - A PoCo-IRC plugin which
keeps you on your favorite channels

=head1 SYNOPSIS

 use POE qw(Component::IRC::State Component::IRC::Plugin::AutoJoin);

 my $nickname = 'Chatter';
 my $server = 'irc.blahblahblah.irc';

 my %channels = (
     '#Blah'   => '',
     '#Secret' => 'secret_password',
     '#Foo'    => '',
 );
 
 POE::Session->create(
     package_states => [
         main => [ qw(_start irc_join) ],
     ],
 );

 $poe_kernel->run();

 sub _start {
     my $irc = POE::Component::IRC::State->spawn( 
         Nick => $nickname,
         Server => $server,
     ) or die "Oh noooo! $!";

     $irc->plugin_add('AutoJoin', POE::Component::IRC::Plugin::AutoJoin->new( Channels => \%channels ));
     $irc->yield(register => qw(join);
     $irc->yield(connect => { } );
 }
 
 sub irc_join {
     my $chan = @_[ARG1];
     $irc->yield(privmsg => $chan => "hi $channel!");
 }


=head1 DESCRIPTION

POE::Component::IRC::Plugin::AutoJoin is a L<POE::Component::IRC|POE::Component::IRC>
plugin. If you get disconnected, the plugin will join all the channels you were
on the next time it gets connected to the IRC server. It can also rejoin a
channel if the IRC component gets kicked from it. It keeps track of channel
keys so it will be able to rejoin keyed channels in case of reconnects/kicks.

This plugin requires the IRC component to be
L<POE::Component::IRC::State|POE::Component::IRC::State> or a subclass thereof.

=head1 METHODS

=head2 C<new>

Two optional arguments:

B<'Channels'>, either an array reference of channel names, or a hash reference
keyed on channel name, containing the password for each channel. By default it
uses the channels the component is already on, if any.

B<'RejoinOnKick'>, set this to 1 if you want the plugin to try to rejoin a
channel (once) if you get kicked from it. Default is 0.

B<'Rejoin_delay'>, the time, in seconds, to wait before rejoining a channel
after being kicked (if B<'RejoinOnKick'> is on). Default is 5.

B<'Retry_when_banned'>, if you can't join a channel due to a ban, set this
to the number of seconds to wait between retries. Default is 0 (disabled).

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s C<plugin_add> method.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
