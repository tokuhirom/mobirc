use t::Utils;
use Test::More tests => 4;
use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Model::Server;

describe 'keyword', sub {
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
    );
    global_context->add_channel($channel);
    isa_ok global_context->get_channel(U '#test'), 'App::Mobirc::Model::Channel';
};


