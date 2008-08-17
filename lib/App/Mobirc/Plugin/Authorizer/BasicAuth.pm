package App::Mobirc::Plugin::Authorizer::BasicAuth;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;
use App::Mobirc::Validator;

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
    my ( $self, $global_context, $req, ) = validate_hook('authorize', @_);

    DEBUG "Basic Auth...";

    my $cred = $self->{username} . ':' . $self->{password};

    my $sent_cred = $req->headers->authorization_basic;
    if ( defined($sent_cred) && $sent_cred eq $cred ) {
        return true;
    }
    else {
        return false;
    }
};

1;
