use t::Utils;
use Test::More tests => 1;
require App::Mobirc::Web::Base;
use Plack::Response;

my $req = HTTP::Request->new('GET', '/?hoge=fuga', ['User-Agent' => 'MYPC']);
test_he $req, sub {
    package t::Web::Base;
    use App::Mobirc::Web::C;
    main::is(param('hoge'), 'fuga');
    Plack::Response->new(200, [], 'hoge');
};

