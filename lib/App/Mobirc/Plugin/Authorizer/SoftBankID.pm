package App::Mobirc::Plugin::Authorizer::SoftBankID;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;
use App::Mobirc::Validator;

has jphone_uid => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook authorize => sub {
    my ( $self, $global_context, $req, ) = validate_hook('authorize', @_);

    my $uid = $req->header('x-jphone-uid');
    if ( $uid && $uid eq $self->jphone_uid ) {
        return true;
    } else {
        return false;
    }
};

1;
