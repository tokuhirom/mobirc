package App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
use strict;
use App::Mobirc::Plugin;
use CSS::Tiny;
use XML::LibXML;
use HTML::Selector::XPath qw(selector_to_xpath);
use App::Mobirc::Util;
use Encode;
use Path::Class;
use XML::LibXML::XPathContext;
use App::Mobirc::Validator;

sub web_context () { App::Mobirc::Web::Handler->web_context } ## no critic
sub mobile_attribute () { web_context->mobile_attribute() } ## no critic

# some code copied from HTML::DoCoMoCSS
hook 'html_filter' => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);

    DEBUG "FILTER DOCOMO CSS";
    return ($req, $content) unless mobile_attribute->is_docomo;

    # escape Numeric character reference.
    $content =~ s/&#(x[\dA-Fa-f]{4}|\d+);/HTMLCSSINLINERESCAPE$1::::::::/g;
    # unescape Numeric character reference.
    my $pict_unescape = sub { $content =~ s/HTMLCSSINLINERESCAPE(x[\dA-Z-a-z]{4}|\d+)::::::::/&#$1;/g; return $content; };

    my $css = CSS::Tiny->read_string($self->css_text($global_context));
    my $doc = eval { XML::LibXML->new->parse_string($content); };
    if (my $e = $@) {
        warn $e;
        return ($req, $pict_unescape->());
    }
    my $xc               = XML::LibXML::XPathContext->new($doc);
    my $root             = $doc->documentElement();
    my $namespace        = $root->getAttribute('xmlns');
    my $namespace_prefix = '';
    if ($namespace) {
        # xhtml
        $xc->registerNs( 'x', $namespace );
        $namespace_prefix = 'x:';
    }

    # apply inline css
    while (my($selector, $style) = each %{ $css }) {
        my $style_stringify = join ';', map { "$_:$style->{$_}" } keys %{ $style };
        my $xpath = selector_to_xpath($selector);
        $xpath =~ s{^//}{//$namespace_prefix};
        for my $element ( $xc->findnodes( $xpath ) ) {
            my $style_attr = $element->getAttribute('style');
            $style_attr = (!$style_attr) ? $style_stringify : (join ";", ($style_attr, $style_stringify));
            $style_attr .= ';' unless $style_attr =~ /;$/;
            $element->setAttribute('style', $style_attr);
        }
    }
    $content = decode_utf8($doc->toString);

    $content =~ s{(<a[^>]+)/>}{$1></a>}gi;

    return ($req, $pict_unescape->());
};

sub css_text {
    my ($self, $global_context) = @_;
    my $root = dir($global_context->config->{global}->{assets_dir}, 'static');
    $root->file('mobirc.css')->slurp . "\n" . $root->file('mobile.css')->slurp;
}

1;
