use t::Utils;
use warnings;
use Test::More;
plan skip_all => 'this test requires XML::LibXML' unless eval 'use XML::LibXML;1;';
plan tests => 1;
use HTTP::MobileAgent;
use App::Mobirc;
require App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
use t::Utils;

my $global_context = App::Mobirc->new(
    config => {
        httpd  => { },
        global => { keywords => [qw/foo/], assets_dir => 'assets' }
    }
);
$global_context->load_plugin('HTMLFilter::DoCoMoCSS');

my $got = <<'...';
<?xml version="1.0"?>
<a href="/" class="time">foo</a>
...
test_he_filter {
    my $req = shift;
    $req->user_agent('DoCoMo/2.0 P2101V(c100)');
    ($req, $got) = $global_context->run_hook_filter('html_filter', $req, $got);
};

my $expected = <<'...';
<?xml version="1.0"?>
<a href="/" class="time" style="color:#004080;">foo</a>
...

is $got, $expected;

