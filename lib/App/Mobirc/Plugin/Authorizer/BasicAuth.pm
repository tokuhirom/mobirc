package App::Mobirc::Plugin::Authorizer::BasicAuth;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;

hook authorize => sub {
    my ( $self, $global_context, $c, $conf ) = @_;

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
};

1;
