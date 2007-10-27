package Mobirc::HTTPD::Authorizer::Cookie;
use strict;
use warnings;
use boolean ':all';
use Carp;

sub authorize {
    my ( $class, $c, $conf ) = @_;

    unless ($c->{config}->{httpd}->{use_cookie}) {
        croak "$class needs enable config->httpd->use_cookie flag";
    }

    my %cookie;
    for ( split( /; */, $c->{req}->header('Cookie') ) ) {
        my ( $name, $value ) = split(/=/);
        $value =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('C', hex($1))/eg;
        $cookie{$name} = $value;
    }

    if (   $cookie{username} eq $conf->{username}
        && $cookie{passwd} eq $conf->{password} )
    {
        return true;
    }
    else {
        return false;
    }
}

1;
