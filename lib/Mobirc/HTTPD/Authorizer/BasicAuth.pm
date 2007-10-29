package Mobirc::HTTPD::Authorizer::BasicAuth;
use strict;
use warnings;
use boolean ':all';
use Carp;

sub authorize {
    my ( $class, $c, $conf ) = @_;

    croak "missing username" unless $conf->{username};
    croak "missing password" unless $conf->{password};

    my $cred = $conf->{username} . ':' . $conf->{password};

    my $sent_cred = $c->{req}->headers->authorization_basic;
    if ( defined($sent_cred) && $sent_cred eq $cred ) {
        return true;
    }
    else {
        return false;
    }
}

1;
