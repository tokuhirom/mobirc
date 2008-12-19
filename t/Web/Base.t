use t::Utils;
use Test::More tests => 1;
use App::Mobirc::Web::Base;

my $req = HTTP::Request->new('GET', '/?hoge=fuga', ['User-Agent' => 'MYPC']);
test_he $req, sub {
    package t::Web::Base;
    use App::Mobirc::Web::C;
    main::is(param('hoge'), 'fuga');
    HTTP::Engine::Response->new(status => 200, body => 'hoge');
};

