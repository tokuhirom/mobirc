package Mobirc::Plugin::Authorizer::BasicAuth;
use strict;
use warnings;
use Carp;
use Mobirc::Util;

sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        'authorize' => sub { my $c = shift;  _authorize($c, $conf) },
    );
}

sub _authorize {
    my ( $c, $conf ) = @_;

    DEBUG "Basic Auth...";

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
