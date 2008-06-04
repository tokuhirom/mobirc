use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Model::Server;

App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] }
    }
);

sub context () { App::Mobirc->context }
sub server () { context->server }
sub keyword_channel () { server->get_channel(U "*keyword*") }
sub test_channel    () { server->get_channel(U '#test') }

sub describe ($&) {
    my ($name, $code) = @_;

    $code->();
    keyword_channel->clear_unread();
}

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
        context, U '#test',
    );
    context->add_channel($channel);
    isa_ok context->get_channel(U '#test'), 'App::Mobirc::Model::Channel';
};

# TODO: move to Model/Server.t
describe 'channels', sub {
    my @channels = server->channels;
    is scalar(@channels), 2;
    isa_ok $channels[0], 'App::Mobirc::Model::Channel';

    my $channels = server->channels;
    is ref($channels), 'ARRAY';
    is_deeply $channels, \@channels;
};

