use t::Utils;
use warnings;
use t::Utils;
use App::Mobirc::Web::View;
use App::Mobirc::Model::Server;
use HTTP::MobileAgent;

use Test::More tests => 3;

my $server = App::Mobirc::Model::Server->new;

my $content;
test_he_filter {
    $content = App::Mobirc::Web::View->show(
        'MobileAjax', 'index'
    );
};
like $content, qr{\Qhttp://www.w3.org/1999/xhtml}, 'html';
like $content, qr{Mobirc\.setUp}, 'included javascript';
like $content, qr{ul\.log li}, 'included css';
