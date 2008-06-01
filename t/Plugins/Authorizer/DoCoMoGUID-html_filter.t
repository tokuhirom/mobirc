use strict;
use warnings;
use Test::More tests => 1;
use App::Mobirc;
use HTTP::Engine middlewares => [
    qw/ +App::Mobirc::HTTPD::Middleware::MobileAgent /
];

my $mobirc = App::Mobirc->new(
    {
        httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin( {module => 'Authorizer::DoCoMoGUID', config => {docomo_guid => 'foobar.docomo'}} );

my $html = '<a href="/">foo</a>';

my ($c, $got) = $mobirc->run_hook_filter('html_filter', create_c(), $html);

is $got, '<a href="/?guid=ON">foo</a>';

sub create_c {
    my $c = HTTP::Engine::Context->new;
    $c->req->user_agent('DoCoMo/2.0 SH904i(c100;TB;W24H16)');
    $c;
}
