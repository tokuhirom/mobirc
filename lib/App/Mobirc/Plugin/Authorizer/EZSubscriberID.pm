package App::Mobirc::Plugin::Authorizer::EZSubscriberID;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;

has 'au_subscriber_id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook authorize => sub {
    my ( $self, $global_context, $c, ) = @_;

    my $subno = $c->req->header('x-up-subno');
    if ( $subno && $subno eq $self->au_subscriber_id ) {
        DEBUG "SUCESS AT EZSubscriberID";
        return true;
    } else {
        return false;
    }
};

1;
