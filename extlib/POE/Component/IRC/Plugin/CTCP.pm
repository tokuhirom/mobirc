package POE::Component::IRC::Plugin::CTCP;

use strict;
use warnings;
use Carp;
use POE::Component::IRC::Plugin qw( :ALL );
use POSIX qw(strftime);

our $VERSION = '6.02';

sub new {
    my ($package) = shift;
    croak "$package requires an even number of arguments" if @_ & 1;
    my %args = @_;
    
    $args{ lc $_ } = delete $args{ $_ } for keys %args;
    $args{eat} = 1 if !defined ( $args{eat} ) || $args{eat} eq '0';
    return bless \%args, $package;
}

sub PCI_register {
    my ($self,$irc) = splice @_, 0, 2;

    $self->{irc} = $irc;
    $irc->plugin_register( $self, 'SERVER', qw(ctcp_version ctcp_userinfo ctcp_time ctcp_ping ctcp_source) );

    return 1;
}

sub PCI_unregister {
    delete $_[0]->{irc};
    return 1;
}

sub S_ctcp_version {
    my ($self, $irc) = splice @_, 0, 2;
    my $nick = ( split /!/, ${ $_[0] } )[0];

    $irc->yield( ctcpreply => $nick => 'VERSION ' . ( defined $self->{version}
            ? $self->{version}
            : "POE::Component::IRC-$POE::Component::IRC::VERSION"
    ));
    return PCI_EAT_CLIENT if $self->eat();
    return PCI_EAT_NONE;
}

sub S_ctcp_time {
    my ($self, $irc) = splice @_, 0, 2;
    my $nick = ( split /!/, ${ $_[0] } )[0];

    $irc->yield( ctcpreply => $nick => strftime( 'TIME %a %h %e %T %Y %Z', localtime ) );
    
    return PCI_EAT_CLIENT if $self->eat();
    return PCI_EAT_NONE;
}

sub S_ctcp_ping {
    my ($self,$irc) = splice @_, 0, 2;
    my $nick = ( split /!/, ${ $_[0] } )[0];
    
    $irc->yield( ctcpreply => $nick => "PING " . time() );
    
    return PCI_EAT_CLIENT if $self->eat();
    return PCI_EAT_NONE;
}

sub S_ctcp_userinfo {
    my ($self, $irc) = splice @_, 0, 2;
    my $nick = ( split /!/, ${ $_[0] } )[0];

    $irc->yield( ctcpreply => $nick => 'USERINFO ' . ( $self->{userinfo} ? $self->{userinfo} : 'm33p' ) );
    
    return PCI_EAT_CLIENT if $self->eat();
    return PCI_EAT_NONE;
}

sub S_ctcp_source {
    my ($self, $irc) = splice @_, 0, 2;
    my $nick = ( split /!/, ${ $_[0] } )[0];

    $irc->yield( ctcpreply => $nick => 'SOURCE ' . ($self->{source}
        ? $self->{source}
        : 'http://search.cpan.org/dist/POE-Component-IRC'
    ));
    
    return PCI_EAT_CLIENT if $self->eat();
    return PCI_EAT_NONE;
}

sub eat {
    my $self = shift;
    my $value = shift;

    return $self->{eat} if !defined $value;
    return $self->{eat} = $value;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::CTCP - A PoCo-IRC plugin that auto-responds to CTCP requests

=head1 SYNOPSIS

 use strict;
 use warnings;
 use POE qw(Component::IRC Component::IRC::Plugin::CTCP);

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
     # Create and load our CTCP plugin
     $irc->plugin_add( 'CTCP' => POE::Component::IRC::Plugin::CTCP->new(
         version => $ircname,
         userinfo => $ircname,
     ));

     $irc->yield( register => 'all' );
     $irc->yield( connect => { } );
     return:
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::CTCP is a L<POE::Component::IRC|POE::Component::IRC>
plugin. It watches for C<irc_ctcp_version>, C<irc_ctcp_userinfo>,
C<irc_ctcp_ping>, C<irc_ctcp_time> and C<irc_ctcp_source> events and
autoresponds on your behalf.

=head1 METHODS

=head2 C<new>

Takes a number of optional arguments:

B<'version'>, a string to send in response to C<irc_ctcp_version>. Default is
PoCo-IRC and version;

B<'userinfo'>, a string to send in response to C<irc_ctcp_userinfo>. Default is
'm33p';

B<'source'>, a string to send in response to C<irc_ctcp_source>. Default is
L<http://search.cpan.org/dist/POE-Component-IRC>.

B<'eat'>, by default the plugin uses PCI_EAT_CLIENT, set this to 0 to disable this
behaviour;

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s C<plugin_add> method.

=head2 C<eat>

With no arguments, returns true or false on whether the plugin is "eating" CTCP
events that it has dealt with. An argument will set "eating" to on or off
appropriately, depending on whether the value is true or false.

=head1 AUTHOR

Chris 'BinGOs' Williams

=head1 SEE ALSO

CTCP Specification L<http://www.irchelp.org/irchelp/rfc/ctcpspec.html>.

=cut
