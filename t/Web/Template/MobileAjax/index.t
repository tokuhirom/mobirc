use strict;
use warnings;
use App::Mobirc::Web::View;
use App::Mobirc::Model::Server;
use HTTP::MobileAgent;
use App::Mobirc::Web::Middleware::MobileAgent;
use Test::More tests => 3;

my $server = App::Mobirc::Model::Server->new;

my $c = App::Mobirc->new(
    config => {
        httpd => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/], assets_dir => 'assets/' },
    }
);

my $content = App::Mobirc::Web::View->show(
    'mobile-ajax/index' => (
        channels     => scalar( $server->channels ),
        mobile_agent => HTTP::MobileAgent->new('DoCoMo'),
        docroot      => '/foo/',
    )
);
like $content, qr{http://www.w3.org/1999/xhtml}, 'html';
like $content, qr{Mobirc\.setUp}, 'included javascript';
like $content, qr{ul.log li}, 'included css';
