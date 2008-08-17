use strict;
use warnings;
use Test::More;
use App::Mobirc;
use HTTP::MobileAgent;
use HTTP::Engine::Compat middlewares => [
    qw/ +App::Mobirc::Web::Middleware::MobileAgent /
];

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

my ($c, $got) = $mobirc->run_hook_filter('html_filter', create_req(), $html);

is $got, '<a href="/?guid=ON">foo</a>';

sub create_req {
    my $req = HTTP::Engine::Compat::Context->new->req;
    $req->user_agent('DoCoMo/2.0 SH904i(c100;TB;W24H16)');
    $req;
}
