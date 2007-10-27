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

    if ( $c->{req}->headers->authorization_basic eq $cred ) {
        return true;
    }
    else {
        return false;
    }
}

1;
