package App::Mobirc::Plugin::Authorizer::BasicAuth;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook authorize => sub {
    my ( $self, $global_context, $c, ) = @_;

    DEBUG "Basic Auth...";

    my $cred = $self->{username} . ':' . $self->{password};

    my $sent_cred = $c->req->headers->authorization_basic;
    if ( defined($sent_cred) && $sent_cred eq $cred ) {
        return true;
    }
    else {
        return false;
    }
};

1;
