use t::Utils;
use App::Mobirc::Web::View;
use App::Mobirc::Model::Server;

use Test::More tests => 3;

my $content = test_view('mobile_ajax/index.mt');
like $content, qr{\Qhttp://www.w3.org/1999/xhtml}, 'html';
like $content, qr{Mobirc\.setUp}, 'included javascript';
like $content, qr{ul\.log li}, 'included css';
