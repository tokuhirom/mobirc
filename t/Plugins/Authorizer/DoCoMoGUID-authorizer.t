use strict;
use warnings;
use Test::More;
use App::Mobirc;
use t::Utils;

eval "use HTML::StickyQuery::DoCoMoGUID";
plan skip_all => 'this test needs HTML::StickyQuery::DoCoMoGUID' if $@;
plan tests => 2;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin( {module => 'Authorizer::DoCoMoGUID', config => {docomo_guid => 'foobar.docomo'}} );

test_he_filter {
    my $req = shift;

    $req->header('x-dcmguid' => 'foobar.docomo');
    ok $mobirc->run_hook_first('authorize', $req), 'login succeeded';

    $req->header('x-dcmguid' => 'invalid_login_id');
    ok !$mobirc->run_hook_first('authorize', $req), 'login failed';
};

