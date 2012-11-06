use t::Utils;
use Test::More;
use Test::Requires 'HTML::TreeBuilder::XPath';
plan tests => 1;
use App::Mobirc;
require App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
require App::Mobirc::Web::Handler;

global_context->load_plugin('HTMLFilter::DoCoMoCSS');

my $got = <<'...';
<?xml version="1.0"?>
<a href="/" class="time">foo</a>
...
test_he_filter {
    my $req = shift;
    $req->user_agent('DoCoMo/2.0 P2101V(c100)');
    ($req, $got) = global_context->run_hook_filter('html_filter', $req, $got);
};

my $expected = <<'...';
<html><head></head><body><a class="time" href="/" style="color:#004080;">foo</a></body></html>
...
$expected =~ s/\n$//;

is $got, $expected;

