use strict;
use warnings;
use Test::More tests => 1;
use HTTP::MobileAgent;
use App::Mobirc;
use App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
use t::Utils;

my $global_context = App::Mobirc->new(
    {
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

