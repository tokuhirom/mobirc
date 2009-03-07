# $Id: Qnet.pm,v 1.2 2005/04/24 10:31:28 chris Exp $
#
# POE::Component::IRC::Qnet, by Chris Williams
#
# This module may be used, modified, and distributed under the same
# terms as Perl itself. Please see the license that came with your Perl
# distribution for details.
#

package POE::Component::IRC::Qnet;

use strict;
use warnings;
use Carp;
use POE;
use POE::Component::IRC::Constants qw(:ALL);
use base qw(POE::Component::IRC);

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
  $self->{server} = 'irc.quakenet.org';
  $self->{QBOT} = 'Q@Cserve.quakenet.org';

  return 1;
}

sub _qnet_bot_commands {
    my ($kernel, $state, $self) = @_[KERNEL,STATE,OBJECT];
    my $message = join ' ', @_[ARG0 .. $#_];

    my $pri = $self->{IRC_CMDS}->{'privmsghi'}->[CMD_PRI];
    my $command = "PRIVMSG ";
    my ($target,$cmd) = split(/_/,$state);
    $command .= join(' :',$self->{uc $target},uc($cmd));
    $command = join(' ',$command,$message) if defined ( $message );
    $kernel->yield( 'sl_prioritized', $pri, $command );

    return;
}

sub service_bots {
    my ($self, %args) = @_;

    for my $botname ( qw(QBOT) ) {
        if ( defined ( $args{$botname} ) ) {
            $self->{$botname} = $args{$botname};
        }
    }
    
    return 1;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Qnet - A fully event-driven IRC client module for Quakenet

=head1 SYNOPSIS

 use strict;
 use warnings;
 use POE qw(Component::IRC::Qnet);

 my $nickname = 'Flibble' . $$;
 my $ircname = 'Flibble the Sailor Bot';
 my $port = 6667;
 my $qauth = 'FlibbleBOT';
 my $qpass = 'fubar';
 my @channels = ( '#Blah', '#Foo', '#Bar' );

 # We create a new PoCo-IRC object and component.
 my $irc = POE::Component::IRC::Qnet->spawn( 
     nick => $nickname,
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

     return;
 }

 sub irc_public {
     my ($kernel, $sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0 .. ARG2];
     my $nick = ( split /!/, $who )[0];
     my $channel = $where->[0];

     if ( my ($rot13) = $what =~ /^rot13 (.+)/ ) {
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

POE::Component::IRC::Qnet is an extension to L<POE::Component::IRC|POE::Component::IRC>
specifically for use on Quakenet L<http://www.quakenet.org/>. See the
documentation for L<POE::Component::IRC|POE::Component::IRC> for general usage.
This document covers the extensions.

The module provides a number of additional commands for communicating with the
Quakenet service bot Q.

=head1 METHODS

=head2 C<service_bots>

The component will query Q its default name on Quakenet. If you
wish to override these settings, use this method to configure them. 

 $irc->service_bots(QBOT => 'W@blah.network.net');

In most cases you shouldn't need to mess with these >;o)

=head1 INPUT

The Quakenet service bots accept input as PRIVMSG. This module provides a
wrapper around the L<POE::Component::IRC> "privmsg" command.

=head2 C<qbot_*>

Send commands to the Q bot. Pass additional command parameters as arguments to
the event.

 $kernel->post ('my client' => qbot_auth => $q_user => $q_pass);

=head1 OUTPUT

All output from the Quakenet service bots is sent as NOTICEs.
Use L<C<irc_notice>|POE::Component::IRC/"irc_notice"> to trap these.

=head2 C<irc_whois>

Has all the same hash keys in C<ARG1> as L<POE::Component::IRC|POE::Component::IRC>,
with the addition of B<'account'>, which contains the name of their Q auth account,
if they have authed, or a false value if they haven't.

=head1 BUGS

A few have turned up in the past and they are sure to again. Please use
L<http://rt.cpan.org/> to report any. Alternatively, email the current maintainer.

=head1 AUTHOR

Chris 'BinGOs' Williams E<lt>chris@bingosnet.co.ukE<gt>

Based on the original POE::Component::IRC by:

Dennis Taylor, <dennis@funkplanet.com>

=head1 SEE ALSO

L<POE::Component::IRC>

L<http://www.quakenet.org/>

=cut
