package App::Mobirc::Plugin::HTMLFilter::ConvertPictograms;
use strict;
use MooseX::Plaggerize::Plugin;
use HTML::Entities::ConvertPictogramMobileJp qw(convert_pictogram_entities);
use Params::Validate ':all';
use App::Mobirc::Validator;

hook html_filter => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);

    return (
        $req,
        convert_pictogram_entities(
            mobile_agent => $req->mobile_agent,
            html         => $content,
        )
    );
};

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

