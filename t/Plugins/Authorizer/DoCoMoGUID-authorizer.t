use strict;
use warnings;
use Test::More tests => 2;
use App::Mobirc;
use HTTP::Engine::Context;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin( {module => 'Authorizer::DoCoMoGUID', config => {docomo_guid => 'foobar.docomo'}} );

ok $mobirc->run_hook_first('authorize', create_c('foobar.docomo')), 'login succeeded';
ok !$mobirc->run_hook_first('authorize', create_c('invalid_login_id')), 'login failed';

sub create_c {
    my $guid = shift;
    my $c = HTTP::Engine::Context->new;
    $c->req->header('x-dcmguid' => $guid);
    $c;
}

