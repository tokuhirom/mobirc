use strict;
use warnings;
use App::Mobirc;
use Test::More;
use t::Utils;

eval q{ use HTTP::MobileAgent::Plugin::Locator };
plan skip_all => "HTTP::MobileAgent::Plugin::Locator is not installed." if $@;
plan tests => 3;

my $mobirc = App::Mobirc->new(
    {
        httpd => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] },
    }
);
$mobirc->load_plugin({module => 'GPS', config => {}});

test_he_filter {
    my $req = shift;
    $req->user_agent('DoCoMo/2.0 SH904i(c100;TB;W24H16)');
    $req->query_params(
        { lat => '35.21.03.342', lon => '138.34.45.725', geo => 'wgs84' } );
    $req->path('/channel/%23coderepos/gps_do');

    my $res = $mobirc->run_hook_first('httpd', $req);
    ok $res;
    is $res->status, 302;
    is $res->header('Location'), '/channels/%23coderepos?msg=L:Lat%3A%2035.21.03.342%2C%20Lng%3A%20138.34.45.725';
};

