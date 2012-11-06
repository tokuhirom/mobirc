use t::Utils;
use Test::More tests => 3;
use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Model::Server;

describe 'keyword', sub {
    ok(server);
    test_channel->add_message(
        App::Mobirc::Model::Message->new( body => 'foobar', class => 'public', )
    );

    is keyword_channel->recent_log_count, 1;
    is keyword_channel->recent_log->[0]->body, 'foobar';
};

describe 'stopword', sub {
    test_channel->add_message(
        App::Mobirc::Model::Message->new(
            body  => 'foo31bar',
            class => 'public',
        )
    );

    is keyword_channel->recent_log_count, 0;
};

describe 'add & get', sub {
    my $channel = App::Mobirc::Model::Channel->new(
        name => U '#test',
        server => server(),
    );
    server->add_channel($channel);
    isa_ok server->get_channel(U '#test'), 'App::Mobirc::Model::Channel';
};


