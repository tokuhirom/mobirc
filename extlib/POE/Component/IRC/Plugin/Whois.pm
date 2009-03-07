package POE::Component::IRC::Plugin::Whois;

use strict;
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( PCI_EAT_NONE );
use POE::Component::IRC::Common qw(:ALL);

our $VERSION = '6.02';

sub new {
    return bless { }, shift;
}

sub PCI_register {
    my( $self, $irc ) = @_;
    $irc->plugin_register( $self, 'SERVER', qw(311 313 312 317 319 320 330 338 318 314 369) );
    return 1;
}

sub PCI_unregister {
    return 1;
}

# RPL_WHOISUSER
sub S_311 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my @args = @{ ${ $_[2] } };
    my $real = pop @args;
    my ($rnick,$user,$host) = @args;
    my $nick = u_irc $rnick, $mapping;

    $self->{WHOIS}->{ $nick }->{nick} = $rnick;
    $self->{WHOIS}->{ $nick }->{user} = $user;
    $self->{WHOIS}->{ $nick }->{host} = $host;
    $self->{WHOIS}->{ $nick }->{real} = $real;

    return PCI_EAT_NONE;
}

# RPL_WHOISOPERATOR
sub S_313 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ${ $_[2] }->[0], $mapping;
    my $oper = ${ $_[2] }->[1];

    $self->{WHOIS}->{ $nick }->{oper} = $oper;
    return PCI_EAT_NONE;
}

# RPL_WHOISSERVER
sub S_312 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($nick,$server) = @{ ${ $_[2] } };
    $nick = u_irc $nick, $mapping;

    # This can be returned in reply to either a WHOIS or a WHOWAS *sigh*
    if ( defined $self->{WHOWAS}->{ $nick } ) {
        $self->{WHOWAS}->{ $nick }->{server} = $server;
    }
    else {
        $self->{WHOIS}->{ $nick }->{server} = $server;
    }

    return PCI_EAT_NONE;
}

# RPL_WHOISIDLE
sub S_317 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($nick,@args) = @{ ${ $_[2] } };
    $nick = u_irc $nick, $mapping;

    $self->{WHOIS}->{ $nick }->{idle} = $args[0];
    $self->{WHOIS}->{ $nick }->{signon} = $args[1];

    return PCI_EAT_NONE;
}

# RPL_WHOISCHANNELS
sub S_319 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my @args = @{ ${ $_[2] } };
    my $nick = u_irc shift ( @args ), $mapping;
    my @chans = split / /, shift @args;

    if ( !defined $self->{WHOIS}->{ $nick }->{channels} ) {
        $self->{WHOIS}->{ $nick }->{channels} = [ @chans ];
    }
    else {
        push( @{ $self->{WHOIS}->{ $nick }->{channels} }, @chans );
    }

  return PCI_EAT_NONE;
}

# RPL_WHOISIDENTIFIED ( Freenode hack )
sub S_320 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($nick, $ident) = @{ ${ $_[2] } };

    $self->{WHOIS}->{ u_irc ( $nick, $mapping  ) }->{identified} = $ident;

    return PCI_EAT_NONE;
}

# RPL_WHOISACTUALLY (Hybrid/Ratbox/others)
sub S_338 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ${ $_[2] }->[0], $mapping;
    my $ip = ${ $_[2] }->[1];
    
    $self->{WHOIS}->{ $nick }->{actually} = $ip;
    
    return PCI_EAT_NONE;
}

# RPL_WHOISACCOUNT (ircu)
sub S_330 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my ($nick,$account) = @{ ${ $_[2] } };

    $self->{WHOIS}->{ u_irc ( $nick, $mapping ) }->{account} = $account;

    return PCI_EAT_NONE;
}


# RPL_ENDOFWHOIS
sub S_318 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ${ $_[2] }->[0], $mapping;
    my $whois = delete $self->{WHOIS}->{ $nick };

    $irc->send_event( 'irc_whois', $whois ) if defined $whois;
    return PCI_EAT_NONE;
}

# RPL_WHOWASUSER
sub S_314 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my @args = @{ ${ $_[2] } };
    my $real = pop @args;
    my ($rnick,$user,$host) = @args;
    my $nick = u_irc $rnick, $mapping;

    $self->{WHOWAS}->{ $nick }->{nick} = $rnick;
    $self->{WHOWAS}->{ $nick }->{user} = $user;
    $self->{WHOWAS}->{ $nick }->{host} = $host;
    $self->{WHOWAS}->{ $nick }->{real} = $real;

    return PCI_EAT_NONE;
}

# RPL_ENDOFWHOWAS
sub S_369 {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $nick = u_irc ${ $_[2] }->[0], $mapping;

    my $whowas = delete $self->{WHOWAS}->{ $nick };
    $irc->send_event( 'irc_whowas', $whowas ) if defined $whowas;
    return PCI_EAT_NONE;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::Whois - A PoCo-IRC plugin that generates events
for WHOIS and WHOWAS replies

=head1 DESCRIPTION

POE::Component::IRC::Plugin::Whois is the reimplementation of the C<irc_whois>
and C<irc_whowas> code from L<POE::Component::IRC|POE::Component::IRC> as a
plugin. It is used internally by L<POE::Component::IRC|POE::Component::IRC>
so there is no need to use this plugin yourself.

=head1 METHODS

=head2 C<new>

No arguments required. Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s C<plugin_add> method.


=head1 AUTHOR

Chris "BinGOs" Williams

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

L<POE::Component::IRC::Plugin|POE::Component::IRC::Plugin>

=cut
