# $Id: State.pm,v 1.4 2005/04/28 14:18:19 chris Exp $
#
# POE::Component::IRC::State, by Chris Williams
#
# This module may be used, modified, and distributed under the same
# terms as Perl itself. Please see the license that came with your Perl
# distribution for details.
#

package POE::Component::IRC::State;

use strict;
use warnings;
use POE;
use POE::Component::IRC::Common qw(:ALL);
use POE::Component::IRC::Plugin qw(:ALL);
use base qw(POE::Component::IRC);

our $VERSION = '2.52';

# Event handlers for tracking the STATE. $self->{STATE} is used as our namespace.
# u_irc() is used to create unique keys.

# RPL_WELCOME
# Make sure we have a clean STATE when we first join the network and if we inadvertently get disconnected
sub S_001 {
    my $self = shift;
    delete $self->{STATE};
    $self->{STATE}->{usermode} = '';
    $self->yield(mode => $self->{RealNick} );
    return PCI_EAT_NONE;
}

sub S_disconnected {
    my $self = shift;
    my $nickinfo = $self->nick_info( $self->{RealNick} );
    my $channels = $self->channels();
    push @{ $_[-1] }, $nickinfo, $channels;
    delete $self->{STATE};
    return PCI_EAT_NONE;
}

sub S_error {
    my $self = shift;
    my $nickinfo = $self->nick_info( $self->{RealNick} );
    my $channels = $self->channels();
    push @{ $_[-1] }, $nickinfo, $channels;
    delete $self->{STATE};
    return PCI_EAT_NONE;
}

sub S_socketerr {
    my $self = shift;
    my $nickinfo = $self->nick_info( $self->{RealNick} );
    my $channels = $self->channels();
    push @{ $_[-1] }, $nickinfo, $channels;
    delete $self->{STATE};
    return PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($nick, $user, $host) = split /[!@]/, ${ $_[0] };
    my $channel = ${ $_[1] };
    my $uchan = u_irc $channel, $mapping;
    my $unick = u_irc $nick, $mapping;

    if ( $unick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE}->{Chans}->{ $uchan };
        $self->{CHANNEL_SYNCH}->{ $uchan } = { MODE => 0, WHO => 0, BAN => 0, _time => time() };
        $self->{STATE}->{Chans}->{ $uchan } = { Name => $channel, Mode => '' };
        $self->yield(who => $channel );
        $self->yield(mode => $channel );
        $self->yield(mode => $channel => 'b');
        
        if ($self->{awaypoll}) {
            $poe_kernel->state(_away_sync => $self);
            $poe_kernel->delay_add(_away_sync => $self->{awaypoll} => $channel);
        }
    }
    else {
        if ( (!exists $self->{whojoiners} || $self->{whojoiners})
            && !exists $self->{STATE}->{Nicks}->{ $unick }->{Real}) {
                $self->yield(who => $nick);
                push @{ $self->{NICK_SYNCH}->{ $unick } }, $channel;
        }
        else {
            # Fake 'irc_nick_sync'
            $self->_send_event(irc_nick_sync => $nick, $channel);
        }
    }

    $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $nick;
    $self->{STATE}->{Nicks}->{ $unick }->{User} = $user;
    $self->{STATE}->{Nicks}->{ $unick }->{Host} = $host;
    $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } = '';
    $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick } = '';
    
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ( ( split /!/, ${ $_[0] } )[0], $mapping );
    my $uchan = u_irc ${ $_[1] }, $mapping;

    if ( $nick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE}->{Nicks}->{ $nick }->{CHANS}->{ $uchan };
        delete $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $nick };
        
        for my $member ( keys %{ $self->{STATE}->{Chans}->{ $uchan }->{Nicks} } ) {
            delete $self->{STATE}->{Nicks}->{ $member }->{CHANS}->{ $uchan };
            if ( keys %{ $self->{STATE}->{Nicks}->{ $member }->{CHANS} } <= 0 ) {
                delete $self->{STATE}->{Nicks}->{ $member };
            }
        }
        
        delete $self->{STATE}->{Chans}->{ $uchan };
    }
    else {
        delete $self->{STATE}->{Nicks}->{ $nick }->{CHANS}->{ $uchan };
        delete $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $nick };
        if ( !keys %{ $self->{STATE}->{Nicks}->{ $nick }->{CHANS} } ) {
            delete $self->{STATE}->{Nicks}->{ $nick };
        }
    }
    
    return PCI_EAT_NONE;
}

sub S_quit {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = ( split /!/, ${ $_[0] } )[0];
    my $msg = ${ $_[1] };
    push @{ $_[2] }, [ $self->nick_channels( $nick ) ];
    my $unick = u_irc $nick, $mapping;

    # Check if it is a netsplit
#    if ($msg) {
#        SWITCH: {
#            my @args = split /\s/, $msg;
#            if ( @args != 2 ) {
#                last SWITCH;
#           }
#        }
#    }

    if ( $unick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE};
    }
    else {
        for my $uchan ( keys %{ $self->{STATE}->{Nicks}->{ $unick }->{CHANS} } ) {
            delete $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick };
        }
        
        delete $self->{STATE}->{Nicks}->{ $unick };
    }

    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my $channel = ${ $_[1] };
    my $nick = ${ $_[2] };
    push @{ $_[-1] }, $self->nick_long_form( $nick );
    my $unick = u_irc $nick, $mapping;
    my $uchan = u_irc $channel, $mapping;

    if ( $unick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan };
        delete $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick };
        
        for my $member ( keys %{ $self->{STATE}->{Chans}->{ $uchan }->{Nicks} } ) {
            delete $self->{STATE}->{Nicks}->{ $member }->{CHANS}->{ $uchan };
            if ( keys %{ $self->{STATE}->{Nicks}->{ $member }->{CHANS} } <= 0 ) {
                delete $self->{STATE}->{Nicks}->{ $member };
            }
        }
        
        delete $self->{STATE}->{Chans}->{ $uchan };
    }
    else {
        delete $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan };
        delete $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick };
        if ( keys %{ $self->{STATE}->{Nicks}->{ $unick }->{CHANS} } <= 0 ) {
            delete $self->{STATE}->{Nicks}->{ $unick };
        }
    }
    
    return PCI_EAT_NONE;
}

sub S_nick {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = ( split /!/, ${ $_[0] } )[0];
    my $new = ${ $_[1] };
    push @{ $_[2] }, [ $self->nick_channels( $nick ) ];
    my $unick = u_irc $nick, $mapping;
    my $unew = u_irc $new, $mapping;

    $self->{RealNick} = $new if $nick eq $self->{RealNick};

    if ($unick eq $unew) {
        # Case Change
        $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $new;
    }
    else {
        my $user = delete $self->{STATE}->{Nicks}->{ $unick };
        $user->{Nick} = $new;
        
        for my $channel ( keys %{ $user->{CHANS} } ) {
           $self->{STATE}->{Chans}->{ $channel }->{Nicks}->{ $unew } = $user->{CHANS}->{ $channel };
           delete $self->{STATE}->{Chans}->{ $channel }->{Nicks}->{ $unick };
        }
        
        $self->{STATE}->{Nicks}->{ $unew } = $user;
    }

    return PCI_EAT_NONE;
}

sub S_chan_mode {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my $who = ${ $_[0] };
    my $channel = ${ $_[1] };
    my $mynick = u_irc $self->nick_name(), $mapping;
    pop @_;
    my $mode = ${ $_[2] };
    my $arg = ${ $_[3] };
    
    return PCI_EAT_NONE if $mode !~ /\+[qoah]/ || $mynick ne u_irc( $arg, $mapping );
    
    my $excepts = $irc->isupport('EXCEPTS');
    my $invex = $irc->isupport('INVEX');
    $irc->yield(mode => $channel, $excepts ) if $excepts;
    $irc->yield(mode => $channel, $invex ) if $invex;
    
    return PCI_EAT_NONE;
}

# RPL_UMODEIS
sub S_221 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mode = ${ $_[1] };
    $mode =~ s/^\+//;
    $self->{STATE}->{usermode} = $mode;
    return PCI_EAT_NONE;
}

# RPL_UNAWAY
sub S_305 {
    my ($self, $irc) = splice @_, 0, 2;
    $self->{STATE}->{away} = 0;
    return PCI_EAT_NONE;
}

# RPL_NOWAWAY
sub S_306 {
    my ($self, $irc) = splice @_, 0, 2;
    $self->{STATE}->{away} = 1;
    return PCI_EAT_NONE;
}

# this code needs refactoring
## no critic
sub S_mode {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $who = ${ $_[0] };
    my $channel = ${ $_[1] };
    my $uchan = u_irc $channel, $mapping;
    pop @_;
    my @modes = map { ${ $_ } } @_[2 .. $#_];

    # CHANMODES is [$list_mode, $always_arg, $arg_when_set, $no_arg]
    # A $list_mode always has an argument
    my $prefix = $irc->isupport('PREFIX') || { 'o', '@', 'v', '+' };
    my $statmodes = join '', keys %{ $prefix };
    my $chanmodes = $irc->isupport('CHANMODES') || [ qw(beI k l imnpstaqr) ];
    my $alwaysarg = join '', $statmodes,  @{ $chanmodes }[0 .. 1];

    # Do nothing if it is UMODE
    if ( $uchan ne u_irc ( $self->{RealNick}, $mapping ) ) {
        my $parsed_mode = parse_mode_line( $prefix, $chanmodes, @modes );
        for my $mode (@{ $parsed_mode->{modes} }) {
            my $arg;
            $arg = shift ( @{ $parsed_mode->{args} } ) if ( $mode =~ /^(.[$alwaysarg]|\+[$chanmodes->[2]])/ );

            $self->_send_event(irc_chan_mode => $who, $channel, $mode, $arg );
            my $flag;
            
            if (($flag) = $mode =~ /\+([$statmodes])/ ) {
                $arg = u_irc $arg, $mapping;
                if (!$self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan } || $self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan } !~ /$flag/) {
                    $self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan } .= $flag;
                    $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $arg } = $self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan };
                }
            }
            elsif (($flag) = $mode =~ /-([$statmodes])/ ) {
                $arg = u_irc $arg, $mapping;
                if ($self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan } =~ /$flag/) {
                    $self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan } =~ s/$flag//;
                    $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $arg } = $self->{STATE}->{Nicks}->{ $arg }->{CHANS}->{ $uchan };
                }
            }
            elsif (($flag) = $mode =~ /\+([$chanmodes->[0]])/ ) {
                $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $flag }->{ $arg } = { SetBy => $who, SetAt => time() };
            }
            elsif (($flag) = $mode =~ /-([$chanmodes->[0]])/ ) {
                delete $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $flag }->{ $arg };
            }

            # All unhandled modes with arguments
            elsif (($flag) = $mode =~ /\+([^$chanmodes->[3]])/ ) {
                $self->{STATE}->{Chans}->{ $uchan }->{Mode} .= $flag if $self->{STATE}->{Chans}->{ $uchan }->{Mode} !~ /$flag/;
                $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{ $flag } = $arg;
            }
            elsif (($flag) = $mode =~ /-([^$chanmodes->[3]])/ ) {
                $self->{STATE}->{Chans}->{ $uchan }->{Mode} =~ s/$flag//;
                delete $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{ $flag };
            }

            # Anything else doesn't have arguments so just adjust {Mode} as necessary.
            elsif (($flag) = $mode =~ /^\+(.)/ ) {
                $self->{STATE}->{Chans}->{ $uchan }->{Mode} .= $flag if $self->{STATE}->{Chans}->{ $uchan }->{Mode} !~ /$flag/;
            }
            elsif (($flag) = $mode =~ /^-(.)/ ) {
                if ($self->{STATE}->{Chans}->{ $uchan }->{Mode} =~ /$flag/) {
                    $self->{STATE}->{Chans}->{ $uchan }->{Mode} =~ s/$flag//;
                }
            }
        }
        
        # Lets make the channel mode nice
        if ( $self->{STATE}->{Chans}->{ $uchan }->{Mode} ) {
            $self->{STATE}->{Chans}->{ $uchan }->{Mode} = join('', sort {uc $a cmp uc $b} ( split( //, $self->{STATE}->{Chans}->{ $uchan }->{Mode} ) ) );
        }
        else {
            delete $self->{STATE}->{Chans}->{ $uchan }->{Mode};
        }
    }
    else {
        my $parsed_mode = parse_mode_line( @modes );
        for my $mode (@{ $parsed_mode->{modes} }) {
            $self->_send_event(irc_user_mode => $who, $channel, $mode );
            my $flag;
            if ( ($flag) = $mode =~ /^\+(.)/ ) {
                $self->{STATE}->{usermode} .= $flag if $self->{STATE}->{usermode} !~ /$flag/;
            }
            elsif ( ($flag) = $mode =~ /^-(.)/ ) {
                $self->{STATE}->{usermode} =~ s/$flag// if $self->{STATE}->{usermode} =~ /$flag/;
            }
        }
    }

    return PCI_EAT_NONE;
}



sub S_topic {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    my $who = ${ $_[0] };
    my $channel = ${ $_[1] };
    my $uchan = u_irc $channel, $mapping;
    my $topic = ${ $_[2] };

    $self->{STATE}->{Chans}->{ $uchan }->{Topic} = {
        Value => $topic,
        SetBy => $who,
        SetAt => time(),
    };

    return PCI_EAT_NONE;  
}

# RPL_WHOREPLY
sub S_352 {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    my ($channel,$user,$host,$server,$nick,$status,$rest) = @{ ${ $_[2] } };
    $rest =~ s/^://;
    my ($hops, $real) = split /\s/, $rest, 2;
    my $unick = u_irc $nick, $mapping;
    my $uchan = u_irc $channel, $mapping;

    $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $nick;
    $self->{STATE}->{Nicks}->{ $unick }->{User} = $user;
    $self->{STATE}->{Nicks}->{ $unick }->{Host} = $host;
    
    if ( !exists $self->{whojoiners} || $self->{whojoiners} ) {
        $self->{STATE}->{Nicks}->{ $unick }->{Hops} = $hops;
        $self->{STATE}->{Nicks}->{ $unick }->{Real} = $real;
        $self->{STATE}->{Nicks}->{ $unick }->{Server} = $server;
        $self->{STATE}->{Nicks}->{ $unick }->{IRCop} = 1 if $status =~ /\*/;
    }
    
    if ($self->{awaypoll}) {
        $self->{STATE}->{Nicks}->{ $unick }->{Away} = $status =~ /G/ ? 1 : 0;
    }
    
    if ( exists $self->{STATE}->{Chans}->{ $uchan } ) {
        my $whatever = '';
        my $existing = $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } || '';    
        my $prefix = $irc->isupport('PREFIX') || { 'o', '@', 'v', '+' };

        for my $mode ( keys %{ $prefix } ) {
            if ($status =~ /\Q$prefix->{$mode}/ && $existing !~ /\Q$prefix->{$mode}/ ) {
                $whatever .= $mode;
            }
        }

        $existing .= $whatever if !$existing || $existing !~ /$whatever/;
        $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } = $existing;
        $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick } = $existing;
        $self->{STATE}->{Chans}->{ $uchan }->{Name} = $channel;

        if ($self->{STATE}->{Chans}->{ $uchan }->{AWAY_SYNCH} && $unick ne u_irc($irc->nick_name(), $mapping)) {
            if ( $status =~ /G/ && !$self->{STATE}->{Nicks}->{ $unick }->{Away} ) {
                $self->yield(irc_user_away => $nick, [ $self->nick_channels( $nick ) ] );
            }
            elsif ($status =~ /H/ && $self->{STATE}->{Nicks}->{ $unick }->{Away} ) {
                $self->yield(irc_user_back => $nick, [ $self->nick_channels( $nick ) ] );
            }
        }
    }
    
    return PCI_EAT_NONE;
}

# RPL_ENDOFWHO
sub S_315 {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    #my $channel = ( split / :/, ${ $_[1] } )[0];
    my $channel = ${ $_[2] }->[0];
    my $uchan = u_irc $channel, $mapping;

    if ( exists $self->{STATE}->{Chans}->{ $uchan } ) {
        if ( $self->_channel_sync($channel, 'WHO') ) {
            my $rec = delete $self->{CHANNEL_SYNCH}->{ $uchan };
            $self->_send_event(irc_chan_sync => $channel, time() - $rec->{_time} );
        }
        elsif ( $self->{STATE}->{Chans}->{ $uchan }->{AWAY_SYNCH} ) {
            $self->{STATE}->{Chans}->{ $uchan }->{AWAY_SYNCH} = 0;
            $self->_send_event(irc_away_sync_end => $channel );
            $poe_kernel->delay_add(_away_sync => $self->{awaypoll} => $channel );
        }
    }
    else {
        my $chan = shift @{ $self->{NICK_SYNCH}->{ $uchan } };
        delete $self->{NICK_SYNCH}->{ $uchan } if !@{ $self->{NICK_SYNCH}->{ $uchan } };
        $self->_send_event(irc_nick_sync => $channel, $chan );
    }

    return PCI_EAT_NONE;
}

# RPL_CREATIONTIME
sub S_329 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $channel = ${ $_[2] }->[0];
    my $time = ${ $_[2] }->[1];
    my $uchan = u_irc $channel, $mapping;
    
    $self->{STATE}->{Chans}->{ $uchan }->{CreationTime} = $time;
    return PCI_EAT_NONE;
}

# RPL_BANLIST
sub S_367 {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;
    my ($mask, $who, $when) = @args;

    $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{b}->{ $mask } = { SetBy => $who, SetAt => $when };
    return PCI_EAT_NONE;
}

# RPL_ENDOFBANLIST
sub S_368 {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;

    if ( $self->_channel_sync($channel, 'BAN') ) {
        my $rec = delete $self->{CHANNEL_SYNCH}->{ $uchan };
        $self->_send_event(irc_chan_sync => $channel, time() - $rec->{_time} );
    }

    return PCI_EAT_NONE;
}

# RPL_INVITELIST
sub S_346 {
    my ($self,$irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;
    my ($mask, $who, $when) = @args;
    my $invex = $irc->isupport('INVEX');

    $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $invex }->{ $mask } = {
        SetBy => $who,
        SetAt => $when
    };
    
    return PCI_EAT_NONE;
}

# RPL_ENDOFINVITELIST
sub S_347 {
    my ($self, $irc) = splice @_, 0, 2;

    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;

    $self->_send_event(irc_chan_sync_invex => $channel );
    return PCI_EAT_NONE;
}

# RPL_EXCEPTLIST
sub S_348 {
    my ($self,$irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;
    my ($mask, $who, $when) = @args;
    my $excepts = $irc->isupport('EXCEPTS');

    $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $excepts }->{ $mask } = {
        SetBy => $who,
        SetAt => $when
    };
    return PCI_EAT_NONE;
}

# RPL_ENDOFEXCEPTLIST
sub S_349 {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;
    
    $self->_send_event(irc_chan_sync_excepts => $channel );
    return PCI_EAT_NONE;
}

# RPL_CHANNELMODEIS
sub S_324 {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my $channel = shift @args;
    my $uchan = u_irc $channel, $mapping;
    my $chanmodes = $irc->isupport('CHANMODES') || [ qw(beI k l imnpstaqr) ];

    my $parsed_mode = parse_mode_line( @args );
    for my $mode (@{ $parsed_mode->{modes} }) {
        $mode =~ s/\+//;
        my $arg = '';
        if ($mode =~ /[^$chanmodes->[3]]/) {
            # doesn't match a mode with no args
            $arg = shift @{ $parsed_mode->{args} };
        }
        
        if ( $self->{STATE}->{Chans}->{ $uchan }->{Mode} ) {
            $self->{STATE}->{Chans}->{ $uchan }->{Mode} .= $mode if $self->{STATE}->{Chans}->{ $uchan }->{Mode} !~ /$mode/;
        }
        else {
            $self->{STATE}->{Chans}->{ $uchan }->{Mode} = $mode;
        }
        
        $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{ $mode } = $arg if defined ( $arg );
    }
    
    if ( $self->{STATE}->{Chans}->{ $uchan }->{Mode} ) {
        $self->{STATE}->{Chans}->{ $uchan }->{Mode} = join('', sort {uc $a cmp uc $b} split //, $self->{STATE}->{Chans}->{ $uchan }->{Mode} );
    }
    
    if ( $self->_channel_sync($channel, 'MODE') ) {
        my $rec = delete $self->{CHANNEL_SYNCH}->{ $uchan };
        $self->_send_event(irc_chan_sync => $channel, time() - $rec->{_time} );
    }

    return PCI_EAT_NONE;
}

# RPL_TOPIC
sub S_332 {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    my $channel = ${ $_[2] }->[0];
    my $topic = ${ $_[2] }->[1];
    my $uchan = u_irc $channel, $mapping;

    $self->{STATE}->{Chans}->{ $uchan }->{Topic}->{Value} = $topic;
    return PCI_EAT_NONE;
}

# RPL_TOPICWHOTIME
sub S_333 {
    my ($self, $irc) = splice @_, 0, 2;
    
    my $mapping = $irc->isupport('CASEMAPPING');
    #my @args = split / /, ${ $_[1] };
    my @args = @{ ${ $_[2] } };
    my ($channel, $who, $when) = @args;
    my $uchan = u_irc $channel, $mapping;

    $self->{STATE}->{Chans}->{ $uchan }->{Topic}->{SetBy} = $who;
    $self->{STATE}->{Chans}->{ $uchan }->{Topic}->{SetAt} = $when;

    return PCI_EAT_NONE;
}

# Methods for STATE query
# Internal methods begin with '_'
#

sub umode {
    my $self = shift;
    return $self->{STATE}->{usermode};
}

sub is_user_mode_set {
    my $self = shift;
    
    my $mode = ( split //, $_[0] )[0] || return;
    $mode =~ s/[^A-Za-z]//g;
    return if !$mode;
    
    return 1 if $self->{STATE}->{usermode} =~ /$mode/;
    return;
}

sub _away_sync {
    my ($self, $channel) = @_[OBJECT, ARG0];
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    
    $self->{STATE}->{Chans}->{ $uchan }->{AWAY_SYNCH} = 1;
    $self->_send_event(irc_away_sync_start => $channel);
    $self->yield(who => $channel );
    
    return;
}

sub _channel_sync {
    my ($self, $channel, $sync) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;

    return if !$self->_channel_exists($channel) || !defined $self->{CHANNEL_SYNCH}->{ $uchan };
    $self->{CHANNEL_SYNCH}->{ $uchan }->{ $sync } = 1 if $sync;

    for my $item ( qw(BAN MODE WHO) ) {
        return if !$self->{CHANNEL_SYNCH}->{ $uchan }->{ $item };
    }

    return 1;
}

sub _nick_exists {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;

    return if !defined $unick;
    return 1 if exists $self->{STATE}->{Nicks}->{ $unick };
    return;
}

sub _channel_exists {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;

    return if !defined $uchan;
    return 1 if exists $self->{STATE}->{Chans}->{ $uchan };
    return;
}

sub _nick_has_channel_mode {
    my ($self, $channel, $nick, $flag) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $unick = u_irc $nick, $mapping;
    $flag = ( split //, $flag )[0];

    return if !$self->is_channel_member($uchan, $unick);
    return 1 if $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } =~ /$flag/;
    return;
}

# Returns all the channels that the bot is on with an indication of
# whether it has operator, halfop or voice.
sub channels {
    my ($self) = @_;
    
    my $mapping = $self->isupport('CASEMAPPING');
    my %result;
    my $realnick = u_irc $self->{RealNick}, $mapping;

    if ( $self->_nick_exists($realnick) ) {
        for my $uchan ( keys %{ $self->{STATE}->{Nicks}->{ $realnick }->{CHANS} } ) {
            $result{ $self->{STATE}->{Chans}->{ $uchan }->{Name} } = $self->{STATE}->{Nicks}->{ $realnick }->{CHANS}->{ $uchan };
        }
    }
    
    return \%result;
}

sub nicks {
    my ($self) = @_;
    return map { $self->{STATE}->{Nicks}->{$_}->{Nick} } keys %{ $self->{STATE}->{Nicks} };
}

sub nick_info {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    
    return if !$self->_nick_exists($nick);

    my $user = $self->{STATE}->{Nicks}->{ $unick };
    my %result = %{ $user };
    $result{Userhost} = $result{User} . '@' . $result{Host};
    delete $result{'CHANS'};

    return \%result;
}

sub nick_long_form {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    
    return if !$self->_nick_exists($nick);
    
    my $user = $self->{STATE}->{Nicks}->{ $unick };
    return $user->{Nick} . '!' . $user->{User} . '@' . $user->{Host};
}

sub nick_channels {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;

    return if !$self->_nick_exists($nick); 
    return map { $self->{STATE}->{Chans}->{$_}->{Name} } keys %{ $self->{STATE}->{Nicks}->{ $unick }->{CHANS} };
}

sub channel_list {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    
    return if !$self->_channel_exists($channel);
    return map { $self->{STATE}->{Nicks}->{$_}->{Nick} } keys %{ $self->{STATE}->{Chans}->{ $uchan }->{Nicks} };
}

sub is_away {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    return if !defined $unick;

    if ($unick eq u_irc $self->{RealNick}) {
        # more accurate
        return 1 if $self->{STATE}->{away};
        return;
    }
    
    return if !$self->_nick_exists($nick);
    return 1 if $self->{STATE}->{Nicks}->{ $unick }->{Away};
    return;
}

sub is_operator {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    
    return if !$self->_nick_exists($nick);
    
    return 1 if $self->{STATE}->{Nicks}->{ $unick }->{IRCop};
    return;
}

sub is_channel_mode_set {
    my ($self, $channel, $mode) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    $mode = ( split //, $mode )[0];

    return if !$self->_channel_exists($channel) || !$mode;
    $mode =~ s/[^A-Za-z]//g;

    if (defined $self->{STATE}->{Chans}->{ $uchan }->{Mode}
        && $self->{STATE}->{Chans}->{ $uchan }->{Mode} =~ /$mode/) {
        return 1;
    }
    
    return;
}

sub is_channel_synced {
    my ($self, $channel) = @_;
    return $self->_channel_sync($channel);
}

sub channel_creation_time {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;

    return if !$self->_channel_exists($channel);
    return if !exists $self->{STATE}->{Chans}->{ $uchan }->{CreationTime};
    
    return $self->{STATE}->{Chans}->{ $uchan }->{CreationTime};
}

sub channel_limit {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    
    return if !$self->_channel_exists($channel);

    if ( $self->is_channel_mode_set($channel, 'l')
        && defined $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{l} ) {
        return $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{l};
    }

    return;
}

sub channel_key {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    return if !$self->_channel_exists($channel);

    if ( $self->is_channel_mode_set($channel, 'k')
        && defined $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{k} ) {
        return $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs}->{k};
    }
    
    return;
}

sub channel_modes {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    return if !$self->_channel_exists($channel);

    my %modes;
    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{Mode} ) {
        %modes = map { ($_ => '') } split(//, $self->{STATE}->{Chans}->{ $uchan }->{Mode});
    }
    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs} ) {
        my %args = %{ $self->{STATE}->{Chans}->{ $uchan }->{ModeArgs} };
        @modes{keys %args} = values %args;
    }
    
    return \%modes;
}

sub is_channel_member {
    my ($self, $channel, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $unick = u_irc $nick, $mapping;

    return if !$self->_channel_exists($channel) || !$self->_nick_exists($nick);    
    return 1 if defined $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick };
    return;
}

sub is_channel_operator {
    my ($self, $channel, $nick) = @_;
    return 1 if $self->_nick_has_channel_mode($channel, $nick, 'o');
    return;
}

sub has_channel_voice {
    my ($self, $channel, $nick) = @_;
    return 1 if $self->_nick_has_channel_mode($channel, $nick, 'v');
    return;
}

sub is_channel_halfop {
    my ($self, $channel, $nick) = @_;
    return 1 if $self->_nick_has_channel_mode($channel, $nick, 'h');
    return;
}

sub is_channel_owner {
    my ($self, $channel, $nick) = @_;
    return 1 if $self->_nick_has_channel_mode($channel, $nick, 'q');
    return;
}

sub is_channel_admin {
    my ($self, $channel, $nick) = @_;
    return 1 if $self->_nick_has_channel_mode($channel, $nick, 'a');
    return;
}

sub ban_mask {
    my ($self, $channel, $mask) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    $mask = parse_ban_mask($mask);
    my @result;

    return if !$self->_channel_exists($channel);

    # Convert the mask from IRC to regex.
    $mask = u_irc ( $mask, $mapping );
    $mask = quotemeta $mask;
    $mask =~ s/\\\*/[\x01-\xFF]{0,}/g;
    $mask =~ s/\\\?/[\x01-\xFF]{1,1}/g;

    for my $nick ( $self->channel_list($channel) ) {
        push @result, $nick if u_irc ( $self->nick_long_form($nick) ) =~ /^$mask$/;
    }
    
    return @result;
}


sub channel_ban_list {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my %result;

    return if !$self->_channel_exists($channel);

    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{b} ) {
        %result = %{ $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{b} };
    }

    return \%result;
}

sub channel_except_list {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $excepts = $self->isupport('EXCEPTS');
    my %result;

    return if !$self->_channel_exists($channel);

    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $excepts } ) {
        %result = %{ $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $excepts } };
    }

    return \%result;
}

sub channel_invex_list {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $invex = $self->isupport('INVEX');
    my %result;

    return if !$self->_channel_exists($channel);

    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $invex } ) {
        %result = %{ $self->{STATE}->{Chans}->{ $uchan }->{Lists}->{ $invex } };
    }

    return \%result;
}

sub channel_topic {
    my ($self, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my %result;

    return if !$self->_channel_exists($channel);

    if ( defined $self->{STATE}->{Chans}->{ $uchan }->{Topic} ) {
        %result = %{ $self->{STATE}->{Chans}->{ $uchan }->{Topic} };
    }

    return \%result;
}

sub nick_channel_modes {
    my ($self, $channel, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $unick = u_irc $nick, $mapping;

    return if !$self->is_channel_member($channel, $nick);

    return $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan };
}

1;
__END__

=head1 NAME

POE::Component::IRC::State - a fully event-driven IRC client module with
channel/nick tracking.

=head1 SYNOPSIS

 # A simple Rot13 'encryption' bot

 use strict;
 use warnings;
 use POE qw(Component::IRC::State);

 my $nickname = 'Flibble' . $$;
 my $ircname = 'Flibble the Sailor Bot';
 my $ircserver = 'irc.blahblahblah.irc';
 my $port = 6667;

 my @channels = ( '#Blah', '#Foo', '#Bar' );

 # We create a new PoCo-IRC object and component.
 my $irc = POE::Component::IRC::State->spawn( 
     nick => $nickname,
     server => $ircserver,
     port => $port,
     ircname => $ircname,
 ) or die "Oh noooo! $!";

 POE::Session->create(
     package_states => [
         main => [ qw(_default _start irc_001 irc_public) ],
     ],
     heap => { irc => $irc },
 );

 $poe_kernel->run();

 sub _start {
     my ($kernel, $heap) = @_[KERNEL, HEAP];

     # We get the session ID of the component from the object
     # and register and connect to the specified server.
     my $irc_session = $heap->{irc}->session_id();
     $kernel->post( $irc_session => register => 'all' );
     $kernel->post( $irc_session => connect => { } );
     return;
 }

 sub irc_001 {
     my ($kernel, $sender) = @_[KERNEL, SENDER];

     # Get the component's object at any time by accessing the heap of
     # the SENDER
     my $poco_object = $sender->get_heap();
     print "Connected to ", $poco_object->server_name(), "\n";

     # In any irc_* events SENDER will be the PoCo-IRC session
     $kernel->post( $sender => join => $_ ) for @channels;
     return;
 }

 sub irc_public {
     my ($kernel ,$sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0 .. ARG2];
     my $nick = ( split /!/, $who )[0];
     my $channel = $where->[0];
     my $poco_object = $sender->get_heap();

     if ( my ($rot13) = $what =~ /^rot13 (.+)/ ) {
         # Only operators can issue a rot13 command to us.
         return if !$poco_object->is_channel_operator( $channel, $nick );

         $rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];
         $kernel->post( $sender => privmsg => $channel => "$nick: $rot13" );
     }
     return;
 }

 # We registered for all events, this will produce some debug info.
 sub _default {
     my ($event, $args) = @_[ARG0 .. $#_];
     my @output = ( "$event: " );

     for my $arg ( @$args ) {
         if (ref $arg  eq 'ARRAY') {
             push( @output, '[' . join(' ,', @$arg ) . ']' );
         }
         else {
             push ( @output, "'$arg'" );
         }
     }
     print join ' ', @output, "\n";
     return 0;
 }

=head1 DESCRIPTION

POE::Component::IRC::State is a sub-class of L<POE::Component::IRC|POE::Component::IRC>
which tracks IRC state entities such as nicks and channels. See the
documentation for L<POE::Component::IRC|POE::Component::IRC> for general usage.
This document covers the extra methods that POE::Component::IRC::State provides.

The component tracks channels and nicks, so that it always has a current
snapshot of what channels it is on and who else is on those channels. The
returned object provides methods to query the collected state.

=head1 CONSTRUCTORS

POE::Component::IRC::State's constructors, and its C<connect> event, all
take the same arguments as L<POE::Component::IRC|POE::Component::IRC> does, as
well as two additional ones:

'AwayPoll', the interval (in seconds) in which to poll (i.e. C<WHO #channel>)
the away status of channel members. Defaults to 0 (disabled). If enabled, you
will receive C<irc_away_sync_*> / L<C<irc_user_away>|/"irc_user_away"> /
L<C<irc_user_back>|/"irc_user_back"> events, and will be able to use the
L<C<is_away>|/"is_away"> method for users other than yourself.

'WhoJoiners', a boolean indicating whether the component should send a
C<WHO nick> for every person which joins a channel. Defaults to on
(the C<WHO> is sent). If you turn this off, L<C<is_operator>|/"is_operator">
will not work and L<C<nick_info>|/"nick_info"> will only return the keys
C<'Nick'>, C<'User'>, C<'Host'> and C<'Userhost'>.

=head1 METHODS

All of the L<POE::Component::IRC|POE::Component::IRC> methods are supported,
plus the following:

=head2 C<umode>

Takes no parameters. Returns the current user mode set for the bot.

=head2 C<is_user_mode_set>

Expects single user mode flag [A-Za-z]. Returns a true value if that user
mode is set.

=head2 C<channels>

Takes no parameters. Returns a hashref, keyed on channel name and whether the
bot is operator, halfop or 
has voice on that channel.

 for my $channel ( keys %{ $irc->channels() } ) {
     $irc->yield( 'privmsg' => $channel => 'm00!' );
 }

If the component happens to not be on any channels an empty hashref is returned.

=head2 C<nicks>

Takes no parameters. Returns a list of all the nicks, including itself, that it
knows about. If the component
happens to be on no channels then an empty list is returned.

=head2 C<channel_list>

Expects a channel as parameter. Returns a list of all nicks on the specified
channel. If the component happens
to not be on that channel an empty list will be returned.

=head2 C<is_away>

Expects a nick as parameter. Returns a true value if the specified nick is away.
Returns a false value if the nick is not away or not in the state. This will
only work for your IRC user unless you specified a value for 'AwayPoll' in
L<C<spawn>|POE::Component::IRC/"spawn">.

=head2 C<is_operator>

Expects a nick as parameter. Returns a true value if the specified nick is
an IRC operator. Returns a false value if the nick is not an IRC operator
or is not in the state.

=head2 C<is_channel_mode_set>

Expects a channel and a single mode flag [A-Za-z]. Returns a true value
if that mode is set on the channel.

=head2 C<channel_creation_time>

Expects a channel as parameter. Returns channel creation time or a false value.

=head2 C<channel_modes>

Expects a channel as parameter. Returns a hash ref keyed on channel mode, with
the mode argument (if any) as the value. Returns a false value instead if the
channel is not in the state.

=head2 C<channel_limit>

Expects a channel as parameter. Returns the channel limit or a false value.

=head2 C<channel_key>

Expects a channel as parameter. Returns the channel key or a false value.

=head2 C<is_channel_member>

Expects a channel and a nickname as parameters. Returns a true value if
the nick is on the specified channel. Returns false if the nick is not on the
channel or if the nick/channel does not exist in the state.

=head2 C<is_channel_owner>

Expects a channel and a nickname as parameters. Returns a true value if
the nick is an owner on the specified channel. Returns false if the nick is
not an owner on the channel or if the nick/channel does not exist in the state.

=head2 C<is_channel_admin>

Expects a channel and a nickname as parameters. Returns a true value if
the nick is an admin on the specified channel. Returns false if the nick is
not an admin on the channel or if the nick/channel does not exist in the state.

=head2 C<is_channel_operator>

Expects a channel and a nickname as parameters. Returns a true value if
the nick is an operator on the specified channel. Returns false if the nick is
not an operator on the channel or if the nick/channel does not exist in the state.

=head2 C<is_channel_halfop>

Expects a channel and a nickname as parameters. Returns a true value if
the nick is a half-operator on the specified channel. Returns false if the nick
is not a half-operator on the channel or if the nick/channel does not exist in
the state.

=head2 C<is_channel_synced>

Expects a channel as a parameter. Returns true if the channel has been synced.
Returns false if it has not been synced or if the channel is not in the state.

=head2 C<has_channel_voice>

Expects a channel and a nickname as parameters. Returns a true value if
the nick has voice on the specified channel. Returns false if the nick does
not have voice on the channel or if the nick/channel does not exist in the state.

=head2 C<nick_long_form>

Expects a nickname. Returns the long form of that nickname, ie. C<nick!user@host>
or a false value if the nick is not in the state.

=head2 C<nick_channels>

Expects a nickname. Returns a list of the channels that that nickname and the
component are on. An empty list will be returned if the nickname does not
exist in the state.

=head2 C<nick_info>

Expects a nickname. Returns a hashref containing similar information to that
returned by WHOIS. Returns a false value if the nickname doesn't exist in the
state. The hashref contains the following keys:

'Nick', 'User', 'Host', 'Userhost', 'Hops', 'Real', 'Server' and, if
applicable, 'IRCop'.

=head2 C<ban_mask>

Expects a channel and a ban mask, as passed to MODE +b-b. Returns a list of
nicks on that channel that match the specified ban mask or an empty list if
the channel doesn't exist in the state or there are no matches.

=head2 C<channel_ban_list>

Expects a channel as a parameter. Returns a hashref containing the banlist
if the channel is in the state, a false value if not. The hashref keys are the
entries on the list, each with the keys 'SetBy' and 'SetAt'. These keys will
hold the nick!hostmask of the user who set the entry (or just the nick if it's
all the ircd gives us), and the time at which it was set respectively.

=head2 C<channel_invex_list>

Expects a channel as a parameter. Returns a hashref containing the invite
exception list if the channel is in the state, a false value if not. The
hashref keys are the entries on the list, each with the keys 'SetBy' and 'SetAt'.
These keys will hold the nick!hostmask of the user who set the entry (or just
the nick if it's all the ircd gives us), and the time at which it was set
respectively.

=head2 C<channel_except_list>

Expects a channel as a parameter. Returns a hashref containing the ban
exception list if the channel is in the state, a false value if not. The
hashref keys are the entries on the list, each with the keys 'SetBy' and
'SetAt'. These keys will hold the nick!hostmask of the user who set the entry
(or just the nick if it's all the ircd gives us), and the time at which it was
set respectively.

=head2 C<channel_topic>

Expects a channel as a parameter. Returns a hashref containing topic
information if the channel is in the state, a false value if not. The hashref
contains the following keys: 'Value', 'SetBy', 'SetAt'. These keys will hold
the topic itself, the nick!hostmask of the user who set it (or just the nick
if it's all the ircd gives us), and the time at which it was set respectively.

=head2 C<nick_channel_modes>

Expects a channel and a nickname as parameters. Returns the modes of the
specified nick on the specified channel (ie. qaohv). If the nick is not on the
channel in the state, a false value will be returned.

=head1 OUTPUT

As well as all the usual L<POE::Component::IRC|POE::Component::IRC> 'irc_*'
events, there are the following events you can register for:

=head2 C<irc_away_sync_start>

Sent whenever the component starts to synchronise the away statuses of channel
members. ARG0 is the channel name. You will only receive this event if you
specified a value for 'AwayPoll' in L<C<spawn>|POE::Component::IRC/"spawn">.

=head2 C<irc_away_sync_end>

Sent whenever the component has completed synchronising the away statuses of
channel members. ARG0 is the channel name. You will only receive this event if
you specified a value for 'AwayPoll' in L<C<spawn>|POE::Component::IRC/"spawn">.

=head2 C<irc_chan_sync>

Sent whenever the component has completed synchronising a channel that it has
joined. ARG0 is the channel name and ARG1 is the time in seconds that the
channel took to synchronise.

=head2 C<irc_chan_sync_invex>

Sent whenever the component has completed synchronising a channel's INVEX
(invite list). Usually triggered by the component being opped on a channel.
ARG0 is the channel name.

=head2 C<irc_chan_sync_excepts>

Sent whenever the component has completed synchronising a channel's EXCEPTS
(ban exemption list). Usually triggered by the component being opped on a
channel. ARG0 is the channel.

=head2 C<irc_nick_sync>

Sent whenever the component has completed synchronising a user who has joined
a channel the component is on. ARG0 is the user's nickname and ARG1 the channel
they have joined.

=head2 C<irc_chan_mode>

This is almost identical to irc_mode, except that it's sent once for each
individual mode with it's respective argument if it has one (ie. the banmask
if it's +b or -b). However, this event is only sent for channel modes.

=head2 C<irc_user_mode>

This is almost identical to irc_mode, except it is sent for each individual
umode that is being set.

=head2 C<irc_user_away>

Sent when an IRC user sets his/her status to away. ARG0 is the nickname, ARG1
is an arrayref of channel names that are common to the nickname and the
component. You will only receive this event if you specified a value for
'AwayPoll' in C<spawn>.

=head2 C<irc_user_back>

Sent when an IRC user unsets his/her away status. ARG0 is the nickname, ARG1
is an arrayref of channel names that are common to the nickname and the
component. You will only receive this event if you specified a value for
'AwayPoll' in L<C<spawn>|POE::Component::IRC/"spawn">.

The following two 'irc_*' events are the same as their
L<POE::Component::IRC|POE::Component::IRC> counterparts, with the additional
parameters:

=head2 C<irc_quit>

ARG2 contains an arrayref of channel names that are common to the quitting
client and the component.

=head2 C<irc_nick>

ARG2 contains an arrayref of channel names that are common to the nick changing
client and the component.

=head2 C<irc_kick>

Additional parameter ARG4 contains the full nick!user@host of the kicked
individual.

=head1 CAVEATS

The component gathers information by registering for 'irc_quit', 'irc_nick',
'irc_join', 'irc_part', 'irc_mode', 'irc_kick' and various numeric replies.
When the component is asked to join a channel, when it joins it will issue
'WHO #channel', 'MODE #channel', and 'MODE #channel b'. These will solicit
between them the numerics, 'irc_352', 'irc_324' and 'irc_329', respectively.
When someone joins a channel the bot is on, it issues a 'WHO nick'. You may
want to ignore these. 

Currently, whenever the component sees a topic or channel list change, it will
use C<time()> for the SetAt value and the full address of the user who set it
for the SetBy value. When an ircd gives us its record of such changes, it will
use its own time (obviously) and may only give us the nickname of the user,
rather than their full address. Thus, if our C<time()> and the ircd's time do
not match, or the ircd uses the nickname only, ugly inconsistencies can develop.
This leaves the SetAt and SetBy values inaccurate at best, and you should use
them with this in mind (for now, at least).

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

With contributions from the Kinky Black Goat.

=head1 LICENCE

This module may be used, modified, and distributed under the same
terms as Perl itself. Please see the license that came with your Perl
distribution for details.

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

L<POE::Component::IRC::Qnet::State|POE::Component::IRC::Qnet::State>

=cut
