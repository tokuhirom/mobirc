package POE::Component::IRC::Plugin::NickServID;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( u_irc );

our $VERSION = '1.2';

sub new {
    my ($package, %self) = @_;
    die "$package requires a Password" if !defined $self{Password};
    return bless \%self, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    $self->{nick} = $irc->{nick};
    $irc->plugin_register($self, 'SERVER', qw(001 nick));
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_001 {
    my ($self, $irc) = splice @_, 0, 2;
    $irc->yield(nickserv => "IDENTIFY $self->{Password}");
    return PCI_EAT_NONE;
}

sub S_nick {
    my ($self, $irc) = splice @_, 0, 2;
    my $mapping = $irc->isupport('CASEMAPPING');
    my $new_nick = u_irc( ${ $_[1] }, $mapping );
    if ( $new_nick eq u_irc($self->{nick}, $mapping) ) {
        $irc->yield(nickserv => "IDENTIFY $self->{Password}");
        return PCI_EAT_NONE;
    }
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::NickServID - A PoCo-IRC plugin
which identifies with FreeNode's NickServ when needed.

=head1 SYNOPSIS

 use POE::Component::IRC::Plugin::NickServID;

 $irc->plugin_add( 'NickServID', POE::Component::IRC::Plugin::NickServID->new(
     Password => 'opensesame'
 ));

=head1 DESCRIPTION

POE::Component::IRC::Plugin::NickServID is a L<POE::Component::IRC|POE::Component::IRC>
plugin. It identifies with NickServ on connect and when you change your nick,
if your nickname matches the supplied password.

B<Note>: If you have a cloak and you don't want to be seen without it, make sure
you identify yourself before joining any channels. If you use the
L<AutoJoin plugin|POE::Component::IRC::Plugin::AutoJoin>, make sure it is
positioned after this one in the plugin pipeline (e.g. load this one first). 

=head1 METHODS

=head2 C<new>

Arguments:

'Password', the NickServ password.

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
