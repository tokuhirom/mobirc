package POE::Component::IRC::Plugin::NickReclaim;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw(:ALL);

our $VERSION = '1.3';

sub new {
    my ($package, %args) = @_;
    $args{ lc $_ } = delete $args{$_} for keys %args;

    if (!defined $args{poll} || $args{poll} !~ /^\d+$/) {
        $args{poll} = 30;
    }
    
    # the $irc->nick_name() and offending nickname will be...
    #...the same on start, thus won't change
    $args{_did_start} = 0;
    $args{_claims} = {};
    
    return bless \%args, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    $irc->plugin_register( $self, 'SERVER', qw(433 001) );
    $irc->plugin_register( $self, 'USER', qw(nick) );
    
    # we will store the original nickname so we would know...
    #...what we need to reclaim, without sending dozens of...
    #...requests to reclaim foo_, foo__, foo___ etc.
    $self->{_nick} = $irc->{nick};
    
    return 1;
}

##############
### sub U_nick
#######
# Basically, since we store the "real" nick in $self->{_nick}
# we need to adjust it if the PoCo::IRC user wants the bot
# to change its nick via ->yield(nick => 'foo');
# problem is that the "reclaiming" process also triggers this event
# we deal with it by using $self->{_claims} which stores all the
# nick with underscores that NickReclaim appended.
#
# if we get a new "real" nick, reset the $self->{_claims}
# and store "real" nick in $self->{_nick} so we would know
# what to reclaim in case we need to.
##############
sub U_nick {
    my $self = shift;
    my ($nick) = $ {$_[1 ]} =~ /^NICK\s+(.+)/i;
    
    return PCI_EAT_NONE if exists $self->{_claims}{ $nick };

    # we got a new "real" nick, reset old nicks with underscores...
    #...we don't need those anymore.
    $self->{_claims} = {};
    $self->{_nick} = $nick;
    
    return PCI_EAT_NONE;
}


sub PCI_unregister {
    return 1;
}

########
## sub S_001
########
# This is basically a tiny little bit that will differentiate
# between successful reclaims and the startup routine 
# when $irc->nick_name() returns the nick which we need to reclaim
######
sub S_001 {
    $_[0]->{_did_start} = 1; 
    return PCI_EAT_NONE;
}


sub S_433 {
    my ($self,$irc) = splice @_, 0, 2;
    
    # this is the nickname which we failed to get...
    my $offending = ${ $_[2] }->[0];
    
    # only reclaim if we don't have a nick we can use...
    #...and it's not a startup routine where ->nick_name cannot
    #...be used (and needs to be reclaimed)
    if (!$self->{_did_start} || $irc->nick_name() eq $offending) {
        # we will store the nick with the underscore in ->{_claims}...
        #...so in sub U_nick{} we would know which ones were caused...
        #...by NickReclaim and which ones need to change the "real" nick
        $offending .= '_';
        $self->{_claims}{ $offending } = 1;
        
        # we will kindly ask the server to give us the nick with an underscore...
        $irc->yield( nick => $offending );
    }

    # cancel old alarm, we won't need it anymore, considering we are going...
    #...to post a new one.
    # BingOS, is there a ->is_still_alarm() method to check if the alarm..
    #...is pending to go off? I couldn't find it in the docs, but would be
    #...nice to have (and use right here)
    $irc->delay_remove( $self->{_alarm_id} );
    $self->{_alarm_id} = $irc->delay(
        [ nick => $self->{_nick} ],
        $self->{poll}
    ); # note that we are asking the server to give us ->{_nick} which is...
    #....our "real" nick.
    
  return PCI_EAT_NONE;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::NickReclaim - A PoCo-IRC plugin for reclaiming
nickname.

=head1 SYNOPSIS

 use strict;
 use warnings;
 use POE qw(Component::IRC Component::IRC::Plugin::NickReclaim);

 my $nickname = 'Flibble' . $$;
 my $ircname = 'Flibble the Sailor Bot';
 my $ircserver = 'irc.blahblahblah.irc';
 my $port = 6667;

 my $irc = POE::Component::IRC->spawn( 
     nick => $nickname,
     server => $ircserver,
     port => $port,
     ircname => $ircname,
 ) or die "Oh noooo! $!";

 POE::Session->create(
     package_states => [
         main => [ qw(_start) ],
     ],
 );

  $poe_kernel->run();

 sub _start {
     $irc->yield( register => 'all' );

     # Create and load our NickReclaim plugin, before we connect 
     $irc->plugin_add( 'NickReclaim' => 
         POE::Component::IRC::Plugin::NickReclaim->new( poll => 30 ) );

     $irc->yield( connect => { } );
     return;
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::NickReclaim - A L<POE::Component::IRC> plugin
automagically deals with your bot's nickname being in use and reclaims it when
it becomes available again.

It registers and handles 'irc_433' events. On receiving a 433 event it will
reset the nickname to the 'nick' specified with spawn() or connect(), appended
with an underscore, and then poll to try and change it to the original nickname. 

=head1 METHODS

=head2 C<new>

Takes one optional argument:

'poll', the number of seconds between nick change attempts, default is 30;

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head1 AUTHOR

Chris 'BinGOs' Williams

With amendments applied by Zoffix Znet

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

=cut
