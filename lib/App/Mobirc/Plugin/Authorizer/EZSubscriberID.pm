package App::Mobirc::Plugin::Authorizer::EZSubscriberID;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;
use App::Mobirc::Validator;

has 'au_subscriber_id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook authorize => sub {
    my ( $self, $global_context, $req, ) = validate_hook('authorize', @_);

    my $subno = $req->header('x-up-subno');
    if ( $subno && $subno eq $self->au_subscriber_id ) {
        DEBUG "SUCESS AT EZSubscriberID";
        return true;
    } else {
        return false;
    }
};

1;
