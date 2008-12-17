use t::Utils;
use Test::More;
plan skip_all => 'this test requires XML::LibXML' unless eval 'use XML::LibXML;1;';
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
<?xml version="1.0"?>
<a href="/" class="time" style="color:#004080;">foo</a>
...

is $got, $expected;

