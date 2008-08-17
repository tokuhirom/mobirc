use strict;
use warnings;
use Test::More;
use App::Mobirc;
use HTTP::MobileAgent;
use t::Utils;

eval "use HTML::StickyQuery::DoCoMoGUID";
plan skip_all => 'this test needs HTML::StickyQuery::DoCoMoGUID' if $@;
plan tests => 1;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin( {module => 'Authorizer::DoCoMoGUID', config => {docomo_guid => 'foobar.docomo'}} );

my $html = '<a href="/">foo</a>';

test_he_filter {
    my $req = shift;
    $req->user_agent('DoCoMo/2.0 SH904i(c100;TB;W24H16)');
    ($req, $html) = $mobirc->run_hook_filter('html_filter', $req, $html);
};

is $html, '<a href="/?guid=ON">foo</a>';

