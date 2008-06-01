use strict;
use warnings;
use Test::More tests => 1;
use HTTP::MobileAgent;
use App::Mobirc;
use App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;
use HTTP::Engine::Context;

my $c = HTTP::Engine::Context->new;
$c->req->user_agent('DoCoMo/2.0 P2101V(c100)');
my $global_context = App::Mobirc->new(
    {
        httpd  => { port     => 3333, },
        global => { keywords => [qw/foo/] }
    }
);
$global_context->load_plugin('HTMLFilter::DoCoMoCSS');

my $got = <<'...';
<style type="text/css">
    a {
        color: red;
    }
</style>
<a href="/">foo</a>
...
($c, $got) = $global_context->run_hook_filter('html_filter', $c, $got);

my $expected = <<'...';
<?xml version="1.0"?>
<a href="/" style="color:red;">foo</a>
...

is $got, $expected;


