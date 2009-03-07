# $Id: State.pm,v 1.4 2005/04/28 14:18:20 chris Exp $
#
# POE::Component::IRC::Qnet::State, by Chris Williams
#
# This module may be used, modified, and distributed under the same
# terms as Perl itself. Please see the license that came with your Perl
# distribution for details.
#

package POE::Component::IRC::Qnet::State;

use strict;
use warnings;
use Carp;
use POE;
use POE::Component::IRC::Common qw(:ALL);
use POE::Component::IRC::Plugin qw(:ALL);
use base qw(POE::Component::IRC::State POE::Component::IRC::Qnet);

our $VERSION = '6.02';

sub _create {
    my $self = shift;

    $self->SUPER::_create();

    # Stuff specific to IRC-Qnet
    my @qbot_commands = qw(
        hello
        whoami
        challengeauth
        showcommands
        auth
        challenge
        help
        unlock
        requestpassword
        reset
        newpass
        email
        authhistory
        banclear
        op
        invite
        removeuser
        banlist
        recover
        limit
        unbanall
        whois
        version
        autolimit
        ban
        clearchan
        adduser
        settopic
        chanflags
        deopall
        requestowner
        bandel
        chanlev
        key
        welcome
        voice
        );

    $self->{OBJECT_STATES_HASHREF}->{'qbot_' . $_} = '_qnet_bot_commands' for @qbot_commands;
    $self->{OBJECT_STATES_HASHREF}->{'resync_chan'} = '_resync_chan';
    $self->{OBJECT_STATES_HASHREF}->{'resync_nick'} = '_resync_nick';
    $self->{server} = 'irc.quakenet.org';
    $self->{QBOT} = 'Q@Cserve.quakenet.org';

    return 1;
}

sub _resync_chan {
    my ($kernel, $self, @channels) = @_[KERNEL, OBJECT, ARG0 .. $#_];

    my $mapping = $self->isupport('CASEMAPPING');
    my $nickname = $self->nick_name();
    my $flags = '%cunharsft';
    
    for my $channel ( @channels ) {
        next if !$self->is_channel_member( $channel, $nickname );

        my $uchan = u_irc $channel, $mapping;
        delete $self->{STATE}->{Chans}->{ $uchan };
        $self->{CHANNEL_SYNCH}->{ $uchan } = { MODE => 0, WHO => 0, BAN => 0, _time => time() };
        $self->{STATE}->{Chans}->{ $uchan } = { Name => $channel, Mode => '' };

        $self->yield ( 'sl' => "WHO $channel $flags,101" );
        $self->yield ( 'mode' => $channel );
        $self->yield ( 'mode' => $channel => 'b');
    }
    
    return;
}

sub _resync_nick {
    my ($kernel, $self, $nick, @channels) = @_[KERNEL ,OBJECT, ARG0 .. $#_];

    my $info = $self->nick_info( $nick );
    return if !$info;
    $nick = $info->{Nick};
    my $user = $info->{User};
    my $host = $info->{Host};
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    my $flags = '%cunharsft';
    
    for my $channel ( @channels ) {
        next if !$self->is_channel_member( $channel, $nick );
        
        my $uchan = u_irc $channel, $mapping;
        $self->yield ( 'sl' => "WHO $nick $flags,102" );
        $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $nick;
        $self->{STATE}->{Nicks}->{ $unick }->{User} = $user;
        $self->{STATE}->{Nicks}->{ $unick }->{Host} = $host;
        $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } = '';
        $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick } = '';
        push @{ $self->{NICK_SYNCH}->{ $unick } }, $channel;
    }
    
    return;
}

# Qnet extension to RPL_WHOIS
sub S_330 {
    my ($self, $irc) = splice @_, 0, 2;
    my ($nick, $account) = ( split / /, ${ $_[1] } )[0..1];

    $self->{WHOIS}->{ $nick }->{account} = $account;
    return PCI_EAT_NONE;
}

# Qnet extension RPL_WHOEXT
sub S_354 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($query, $channel, $user, $host, $server, $nick, $status, $auth, $real)
        = @{ ${ $_[2] } };
    my $unick = u_irc $nick, $mapping;
    my $uchan = u_irc $channel, $mapping;
  
    $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $nick;
    $self->{STATE}->{Nicks}->{ $unick }->{User} = $user;
    $self->{STATE}->{Nicks}->{ $unick }->{Host} = $host;
    $self->{STATE}->{Nicks}->{ $unick }->{Real} = $real;
    $self->{STATE}->{Nicks}->{ $unick }->{Server} = $server;
    $self->{STATE}->{Nicks}->{ $unick }->{Auth} = $auth if ( $auth );
    
    if ( $auth and defined ( $self->{USER_AUTHED}->{ $unick } ) ) {
        $self->{USER_AUTHED}->{ $unick } = $auth;
    }
  
    if ( $query eq '101' ) {
        my $whatever = '';
        $whatever .= 'o' if $status =~ /\@/;
        $whatever .= 'v' if $status =~ /\+/;
        $whatever .= 'h' if $status =~ /\%/;
        $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } = $whatever;
        $self->{STATE}->{Chans}->{ $uchan }->{Name} = $channel;
        $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick } = $whatever;
    }

    if ( $status =~ /\*/ ) {
        $self->{STATE}->{Nicks}->{ $unick }->{IRCop} = 1;
    }
    
    return PCI_EAT_NONE;
}

# RPL_ENDOFWHO
sub S_315 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $channel = ${ $_[2] }->[0];
    my $uchan = u_irc $channel, $mapping;

    if ( exists $self->{STATE}->{Chans}->{ $uchan } ) {
        if ( $self->_channel_sync($channel, 'WHO' ) ) {
            my $rec = delete $self->{CHANNEL_SYNCH}->{ $uchan };
            $self->_send_event( 'irc_chan_sync', $channel, time() - $rec->{_time} );
        }
    }
    # it's apparently a nickname
    elsif ( defined $self->{USER_AUTHED}->{ $uchan } ) {
        $self->_send_event( 'irc_nick_authed', $channel, delete $self->{USER_AUTHED}->{ $uchan } );
    }
    else {
        my $chan = shift @{ $self->{NICK_SYNCH}->{ $uchan } };
        delete $self->{NICK_SYNCH}->{ $uchan } if !@{ $self->{NICK_SYNCH}->{ $uchan } };
        $self->_send_event( 'irc_nick_sync', $channel, $chan );
    }

    return PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    my ($nick, $user, $host) = parse_user(${ $_[0] } );
    my $channel = ${ $_[1] };

    my $mapping = $irc->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    my $unick = u_irc $nick, $mapping;
    my $flags = '%cunharsft';

    if ( $unick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE}->{Chans}->{ $uchan };
        $self->{CHANNEL_SYNCH}->{ $uchan } = {
            MODE => 0,
            WHO => 0,
            BAN => 0,
            _time => time()
        };
        $self->{STATE}->{Chans}->{ $uchan } = { Name => $channel, Mode => '' };
        
        $self->yield ( 'sl' => "WHO $channel $flags,101" );
        $self->yield ( 'mode' => $channel );
        $self->yield ( 'mode' => $channel => 'b');

    }
    else {
        $self->yield ( 'sl' => "WHO $nick $flags,102" );
        $self->{STATE}->{Nicks}->{ $unick }->{Nick} = $nick;
        $self->{STATE}->{Nicks}->{ $unick }->{User} = $user;
        $self->{STATE}->{Nicks}->{ $unick }->{Host} = $host;
        $self->{STATE}->{Nicks}->{ $unick }->{CHANS}->{ $uchan } = '';
        $self->{STATE}->{Chans}->{ $uchan }->{Nicks}->{ $unick } = '';
        push @{ $self->{NICK_SYNCH}->{ $unick } }, $channel;
    }

    return PCI_EAT_NONE;
}

sub S_chan_mode {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $who = ${ $_[0] };
    my $source = u_irc ( ( split /!/, $who )[0], $mapping );
    my $mode = ${ $_[2] };
    my $arg = ${ $_[3] };
    my $uarg = u_irc $arg, $mapping;
    
    return PCI_EAT_NONE if $source !~ /^[Q]$/ || $mode !~ /[ov]/;
    
    if ( !$self->is_nick_authed($arg) && !$self->{USER_AUTHED}->{ $uarg } ) {
       $self->{USER_AUTHED}->{ $uarg } = 0;
       $self->yield ( 'sl' => "WHO $arg " . '%cunharsft,102' );
    }
    
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ( ( split /!/, ${ $_[0] } )[0], $mapping );
    my $channel = u_irc ${ $_[1] }, $mapping;
    if ( ref $_[2] eq 'ARRAY' ) {
        push @{ $_[-1] }, '', $self->is_nick_authed( $nick );
    }
    else {
        push @{ $_[-1] }, $self->is_nick_authed( $nick );
    }

    if ( $nick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE}->{Nicks}->{ $nick }->{CHANS}->{ $channel };
        delete $self->{STATE}->{Chans}->{ $channel }->{Nicks}->{ $nick };
        for my $member ( keys %{ $self->{STATE}->{Chans}->{ $channel }->{Nicks} } ) {
           delete $self->{STATE}->{Nicks}->{ $member }->{CHANS}->{ $channel };
           if ( keys %{ $self->{STATE}->{Nicks}->{ $member }->{CHANS} } <= 0 ) {
                delete $self->{STATE}->{Nicks}->{ $member };
           }
        }
        delete $self->{STATE}->{Chans}->{ $channel };
    }
    else {
        delete $self->{STATE}->{Nicks}->{ $nick }->{CHANS}->{ $channel };
        delete $self->{STATE}->{Chans}->{ $channel }->{Nicks}->{ $nick };
        if ( keys %{ $self->{STATE}->{Nicks}->{ $nick }->{CHANS} } <= 0 ) {
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
    push @{ $_[2] }, $self->is_nick_authed( $nick );
    my $unick = u_irc $nick, $mapping;

    # Check if it is a netsplit
#    if ( $msg ) {
#        SWITCH: {
#            my @args = split /\x20/, $msg;
#            if ( @args != 2 ) {
#                last SWITCH;
#            }
#        }
#    }

    if ( $unick eq u_irc ( $self->nick_name(), $mapping ) ) {
        delete $self->{STATE};
    }
    else {
        for my $channel ( keys %{ $self->{STATE}->{Nicks}->{ $unick }->{CHANS} } ) {
                delete $self->{STATE}->{Chans}->{ $channel }->{Nicks}->{ $unick };
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
    my $unick = u_irc $nick, $mapping;
    my $uchan = u_irc $channel, $mapping;

    push @{ $_[-1] }, $self->nick_long_form( $nick );
    push @{ $_[-1] }, $self->is_nick_authed( $nick );

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

sub is_nick_authed {
    my ($self, $nick) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $unick = u_irc $nick, $mapping;
    
    return if !$self->_nick_exists($nick);

    if (defined $self->{STATE}->{Nicks}->{ $unick }->{Auth}) {
        return $self->{STATE}->{Nicks}->{ $unick }->{Auth};
    }

    return;
}

sub find_auth_nicks {
    my ($self, $auth, $channel) = @_;
    my $mapping = $self->isupport('CASEMAPPING');
    my $uchan = u_irc $channel, $mapping;
    
    return if !$self->_channel_exists($channel);
    my @results;

    for my $nick ( keys %{ $self->{STATE}->{Chans}->{ $uchan }->{Nicks} } ) {
        if (defined ( $self->{STATE}->{Nicks}->{ $nick }->{Auth} )
            && $self->{STATE}->{Nicks}->{ $nick }->{Auth} eq $auth) {
            push @results, $self->{STATE}->{Nicks}->{ $nick }->{Nick};
        }
    }

    return @results; 
}

sub ban_mask {
    my ($self, $channel, $mask) = @_;
    $mask = parse_ban_mask($mask);
    my $mapping = $self->isupport('CASEMAPPING');
    my @result;

    return if !$self->_channel_exists($channel);

    # Convert the mask from IRC to regex.
    $mask = u_irc ( $mask, $mapping );
    $mask = quotemeta $mask;
    $mask =~ s/\\\*/[\x01-\xFF]{0,}/g;
    $mask =~ s/\\\?/[\x01-\xFF]{1,1}/g;

    for my $nick ( $self->channel_list($channel) ) {
        my $long_form = $self->nick_long_form($nick);
        
        if ( u_irc ( $long_form ) =~ /^$mask$/ ) {
            push @result, $nick;
            next;
        }

        if ( my $auth = $self->is_nick_authed( $nick ) ) {
            $long_form =~ s/\@(.+)$/\@$auth.users.quakenet.org/;
            push @result, $nick if u_irc ( $long_form ) =~ /^$mask$/;
        }
    }

    return @result;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Qnet::State - A fully event-driven IRC client module
for Quakenet with nickname and channel tracking

=head1 SYNOPSIS

 # A simple Rot13 'encryption' bot

 use strict;
 use warnings;
 use POE qw(Component::IRC::Qnet::State);

 my $nickname = 'Flibble' . $$;
 my $ircname = 'Flibble the Sailor Bot';
 my $ircserver = 'irc.blahblahblah.irc';
 my $port = 6667;
 my $qauth = 'FlibbleBOT';
 my $qpass = 'fubar';

 my @channels = ( '#Blah', '#Foo', '#Bar' );

 # We create a new PoCo-IRC object and component.
 my $irc = POE::Component::IRC::Qnet::State->spawn( 
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

     # Lets authenticate with Quakenet's Q bot
     $kernel->post( $sender => qbot_auth => $qauth => $qpass );

     # In any irc_* events SENDER will be the PoCo-IRC session
     $kernel->post( $sender => join => $_ ) for @channels;

     return;
 }

 sub irc_public {
     my ($kernel, $sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0, .. ARG2];
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
         if (ref $arg eq 'ARRAY') {
             push( @output, '[' . join(', ', @$arg ) . ']' );
         }
         else {
             push ( @output, "'$arg'" );
         }
     }
     
     print join ' ', @output, "\n";
     return 0;
 }


=head1 DESCRIPTION

POE::Component::IRC::Qnet::State is an extension to
L<POE::Component::IRC::Qnet|POE::Component::IRC::Qnet> specifically for use on
Quakenet L<http://www.quakenet.org/>, which includes the nickname and channel
tracking from L<POE::Component::IRC::State|POE::Component::IRC::State>. See
the documentation for L<POE::Component::IRC::Qnet|POE::Component::IRC::Qnet>
and L<POE::Component::IRC::State|POE::Component::IRC::State> for general usage.
This document covers the extensions.

=head1 METHODS

=over

=item C<ban_mask>

Expects a channel and a ban mask, as passed to MODE +b-b. Returns a list of
nicks on that channel that match the specified ban mask or an empty list if the
channel doesn't exist in the state or there are no matches. Follows Quakenet
ircd rules for matching authed users.

=item C<is_nick_authed>

Expects a nickname as parameter. Will return that users authname (account) if
that nick is in the state  and have authed with Q. Returns a false value if
the user is not authed or the nick doesn't exist in the state.

=item C<find_auth_nicks>

Expects an authname and a channel name. Will return a list of nicks on the
given channel that have authed with the given authname.

=item C<nick_info>

Expects a nickname. Returns a hashref containing similar information to that
returned by WHOIS. Returns a false value if the nickname doesn't exist in the
state. The hashref contains the following keys: B<'Nick'>, B<'User'>,
B<'Host'>, B<'Server'>, B<'Auth'>, if authed, and, if applicable, B<'IRCop'>.

=back

=head1 INPUT

These additional events are accepted:

=over

=item C<resync_chan>

Accepts a list of channels, will resynchronise each of those channels as if
they have been joined for the first time. Expect to see an
L<C<irc_chan_sync>|POE::Component::IRC::State/"irc_chan_sync"> event for each
channel given.

=item C<resync_nick>

Accepts a nickname and a list of channels. Will resynchronise the given nickname
and issue an L<C<irc_nick_sync>|POE::Component::IRC::State/"irc_nick_sync">
event for each of the given channels (assuming that nick is on each of those channels).

=back

=head1 OUTPUT

This module returns one additional event over and above the usual events:

=over

=item C<irc_nick_authed>

Sent when the component detects that a user has authed with Q. Due to the
mechanics of Quakenet you will usually only receive this if an unauthed user
joins a channel, then at some later point auths with Q. The component 'detects'
the auth by seeing if Q decides to +v or +o the user. Klunky? Indeed. But
it is the only way to do it, unfortunately.

=back

The following two C<irc_*> events are the same as their
L<POE::Component::IRC::State|POE::Component::IRC::State> counterparts, with
the additional parameters:

=over

=item C<irc_quit>

C<ARG3> contains the quitting clients auth name if applicable.

=item C<irc_part>

C<ARG3> contains the parting clients auth name if applicable.

=item C<irc_kick>

C<ARG5> contains the kick victim's auth name if applicable.

=back

=head1 CAVEATS

Like L<POE::Component::IRC::State|POE::Component::IRC::State> this component
registers itself for a number of events. The main difference with
L<POE::Component::IRC::State|POE::Component::IRC::State> is that it uses an
extended form of 'WHO' supported by the Quakenet ircd, asuka. This WHO returns
a different numeric reply than the original WHO, namely, C<irc_354>. Also, due
to the way Quakenet is configured all users will appear to be on the server
'*.quakenet.org'.

=head1 BUGS

A few have turned up in the past and they are sure to again. Please use
L<http://rt.cpan.org/> to report any. Alternatively, email the current
maintainer.

=head1 AUTHOR

Chris 'BinGOs' Williams <chris@bingosnet.co.uk>

Based on the original POE::Component::IRC by:

Dennis Taylor

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

L<POE::Component::IRC::State|POE::Component::IRC::State>

L<POE::Component::IRC::Qnet|POE::Component::IRC::Qnet>

L<http://www.quakenet.org/>

=cut
