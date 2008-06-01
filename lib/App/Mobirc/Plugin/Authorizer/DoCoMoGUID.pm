package App::Mobirc::Plugin::Authorizer::DoCoMoGUID;
use strict;
use MooseX::Plaggerize::Plugin;
use Carp;
use App::Mobirc::Util;
use HTML::StickyQuery::DoCoMoGUID;

has docomo_guid => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook authorize => sub {
    my ( $self, $global_context, $c, ) = @_;

    my $subno = $c->req->header('x-dcmguid');
    if ( $subno && $subno eq $self->docomo_guid ) {
        DEBUG "SUCESS AT DocomoGUID";
        return true;
    } else {
        return false;
    }
};

hook 'html_filter' => sub {
    my ($self, $global_context, $c, $content) = @_;

    DEBUG "Filter DoCoMoGUID";
    return $content unless $c->req->mobile_agent->is_docomo;
    return ($c, HTML::StickyQuery::DoCoMoGUID->new()->sticky( scalarref => \$content, ));
};

1;
