package App::Mobirc::Plugin::Authorizer::DoCoMoGUID;
use strict;
use warnings;
use Carp;
use App::Mobirc::Util;

use HTML::StickyQuery::DoCoMoGUID;
sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        'authorize' => sub { my $c = shift;  _authorize($c, $conf) }
    );
    $global_context->register_hook(
        'html_filter' => \&_html_filter_docomo_guid,
    );
}

sub _authorize {
    my ( $c, $conf ) = @_;

    DEBUG __PACKAGE__;

    unless ($conf->{docomo_guid}) {
        croak "missing docomo_guid";
    }

    my $subno = $c->{req}->header('x-dcmguid');
    if ( $subno && $subno eq $conf->{docomo_guid} ) {
        DEBUG "SUCESS AT DocomoGUID";
        return true;
    } else {
        return false;
    }
}

sub _html_filter_docomo_guid {
    my ($c, $content) = @_;

    DEBUG "Filter DoCoMoGUID";
    return $content unless $c->{mobile_agent}->is_docomo;

    return HTML::StickyQuery::DoCoMoGUID->new()->sticky( scalarref => \$content, );
}

1;
