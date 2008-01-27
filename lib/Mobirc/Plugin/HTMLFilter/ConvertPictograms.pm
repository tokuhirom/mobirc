package Mobirc::Plugin::HTMLFilter::ConvertPictograms;
use strict;
use warnings;
use HTML::Entities::ConvertPictogramMobileJp;

sub register {
    my ($class, $global_context) = @_;

    $global_context->register_hook(
        'html_filter' => \&_html_convert_pictograms
    );
}

sub _html_convert_pictograms {
    my ($c, $content) = @_;

    convert_pictogram_entities(
        mobile_agent => $c->{mobile_agent},
        html         => $content,
    );
}

1;
