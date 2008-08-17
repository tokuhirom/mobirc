use strict;
use warnings;
use Test::More;
use App::Mobirc;
use HTTP::Engine::Compat::Context;

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

ok $mobirc->run_hook_first('authorize', create_req('foobar.docomo')), 'login succeeded';
ok !$mobirc->run_hook_first('authorize', create_req('invalid_login_id')), 'login failed';

sub create_req {
    my $guid = shift;
    my $c = HTTP::Engine::Compat::Context->new;
    $c->req->header('x-dcmguid' => $guid);
    $c->req;
}

