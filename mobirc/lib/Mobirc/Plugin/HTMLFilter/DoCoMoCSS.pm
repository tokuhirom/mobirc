package Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
use strict;
use warnings;
use CSS::Tiny;
use XML::LibXML;
use HTML::Selector::XPath;
use Mobirc::Util;

sub register {
    my ($class, $global_context) = @_;

    DEBUG "Register DoCoMoCSS";

    $global_context->register_hook(
        'html_filter' => \&_html_filter_docomocss,
    );
}

# based from HTML::DoCoMoCSS
sub _html_filter_docomocss {
    my $c = shift;
    my $content = shift;

    DEBUG "FILTER DOCOMO CSS";
    return $content unless $c->{mobile_agent}->is_docomo;

    # escape Numeric character reference.
    $content =~ s/&#(x[\dA-Fa-f]{4}|\d+);/HTMLCSSINLINERESCAPE$1::::::::/g;
    # unescape Numeric character reference.
    my $pict_unescape = sub { $content =~ s/HTMLCSSINLINERESCAPE(x[\dA-Z-a-z]{4}|\d+)::::::::/&#$1;/g; return $content; };

    $content =~ s{<style type="text/css">(.+)</style>}{}sm;
    my $css_text = $1 or return $pict_unescape->();

    my $css = CSS::Tiny->read_string($css_text);
    my $doc = eval { XML::LibXML->new->parse_string($content); };
    $@ and return $pict_unescape->();

    # apply inline css
    while (my($selector, $style) = each %{ $css }) {
        my $style_stringify = join ';', map { "$_:$style->{$_}" } keys %{ $style };
        for my $element ( $doc->findnodes( HTML::Selector::XPath::selector_to_xpath($selector) ) ) {
            my $style_attr = $element->getAttribute('style');
            $style_attr = (!$style_attr) ? $style_stringify : (join ";", ($style_attr, $style_stringify));
            $style_attr .= ';' unless $style_attr =~ /;$/;
            $element->setAttribute('style', $style_attr);
        }
    }
    $content = $doc->toString;

    $content =~ s{(<a[^>]+)/>}{$1></a>}gi;

    return $pict_unescape->();
}

1;
