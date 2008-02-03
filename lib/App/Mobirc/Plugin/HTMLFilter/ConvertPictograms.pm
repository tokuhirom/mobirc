package App::Mobirc::Plugin::HTMLFilter::ConvertPictograms;
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
__END__

=head1 NAME

App::Mobirc::Plugin::HTMLFilter::ConvertPictograms - convert pictograms in the template

=head1 SYNOPSIS

  - module: App::Mobirc::Plugin::HTMLFilter::ConvertPictograms

=head1 DESCRIPTION

convert pictograms in the assets/tmpl/mobile/*.html.

if you use the au or softbank phones, you should use this plugin!

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<App::Mobirc>, L<HTML::Entities::ConvertPictogramMobileJp>

