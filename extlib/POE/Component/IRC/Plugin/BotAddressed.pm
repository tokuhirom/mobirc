package POE::Component::IRC::Plugin::BotAddressed;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );

sub new {
    my ($package, %args) = @_;
    $args{lc $_} = delete $args{$_} for keys %args;
    return bless \%args, $package;
}

sub PCI_register {
    my ($self, $irc) = splice @_, 0, 2;
    $irc->plugin_register( $self, 'SERVER', qw(ctcp_action public) );
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_ctcp_action {
    my ($self, $irc) = splice @_, 0, 2;
    my $who = ${ $_[0] };
    my $recipients = ${ $_[1] };
    my $what = ${ $_[2] };
    my $me = $irc->nick_name();

    my $eat = PCI_EAT_NONE;
    return $eat if $what !~ /$me/i;
    
    for my $recipient (@{ $recipients }) {
        if ($recipient =~ /^[#&+!]/) {
            $eat = PCI_EAT_ALL if $self->{eat};
            $irc->send_event(irc_bot_mentioned_action => $who => [$recipient] => $what);
        }
    }
    
    return $eat;
}

sub S_public {
    my ($self, $irc) = splice @_, 0, 2;
    my $who = ${ $_[0] };
    my $channels = ${ $_[1] };
    my $what = ${ $_[2] };
    my $me = $irc->nick_name();
    my ($cmd) = $what =~ m/^\s*\Q$me\E[:,;.!?]?\s*(.*)$/i;
    
    return PCI_EAT_NONE if !defined $cmd && $what !~ /$me/i;
    
    for my $channel (@{ $channels }) {
        if (defined $cmd) {
            $irc->send_event(irc_bot_addressed => $who => [$channel] => $cmd );
        }
        else {
            $irc->send_event(irc_bot_mentioned => $who => [$channel] => $what);
        }
    }
  
    return $self->{eat} ? PCI_EAT_ALL : PCI_EAT_NONE;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::BotAddressed - A PoCo-IRC plugin that generates
an 'irc_bot_addressed', 'irc_bot_mentioned' or 'irc_bot_mentioned_action' event
if its name comes up in channel discussion.

=head1 SYNOPSIS

 use POE::Component::IRC::Plugin::BotAddressed;

 $irc->plugin_add( 'BotAddressed', POE::Component::IRC::Plugin::BotAddressed->new() );

 sub irc_bot_addressed {
     my ($kernel, $heap) = @_[KERNEL, HEAP];
     my $nick = ( split /!/, $_[ARG0] )[0];
     my $channel = $_[ARG1]->[0];
     my $what = $_[ARG2];

     print "$nick addressed me in channel $channel with the message '$what'\n";
 }

 sub irc_bot_mentioned {
     my ($nick) = ( split /!/, $_[ARG0] )[0];
     my ($channel) = $_[ARG1]->[0];
     my ($what) = $_[ARG2];

     print "$nick mentioned my name in channel $channel with the message '$what'\n";
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::BotAddressed is a L<POE::Component::IRC|POE::Component::IRC>
plugin. It watches for public channel traffic (i.e. 'irc_public' and
'irc_ctcp_action') and will generate an 'irc_bot_addressed', 'irc_bot_mentioned'
or 'irc_bot_mentioned_action' event if its name comes up in channel discussion.

It uses L<POE::Component::IRC|POE::Component::IRC>'s nick_name() method to work
out its current nickname.

=head1 METHODS

=head2 C<new>

One optional argument:

'eat', set to true to make the plugin eat the 'irc_public' / 'irc_ctcp_action'
event and only generate an appropriate event, default is false.

Returns a plugin object suitable for feeding to L<POE::Component::IRC|POE::Component::IRC>'s
plugin_add() method.

=head1 OUTPUT

=head2 C<irc_bot_addressed>

Has the same parameters passed as L<C<irc_ctcp_action>|POE::Component::IRC/"irc_ctcp_action">.
ARG2 contains the message with the addressed nickname removed, ie. Assuming
that your bot is called LameBOT, and someone says 'LameBOT: dance for me',
you will actually get 'dance for me'.

=head2 C<irc_bot_mentioned>

Has the same parameters passed as L<C<irc_public>|POE::Component::IRC/"irc_public">.

=head2 C<irc_bot_mentioned_action>

Has the same parameters passed as L<C<irc_ctcp_action>|POE::Component::IRC/"irc_ctcp_action">.

=head1 AUTHOR

Chris 'BinGOs' Williams <chris@bingosnet.co.uk>

=cut
