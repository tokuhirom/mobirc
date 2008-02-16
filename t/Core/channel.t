use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Channel;
use App::Mobirc::Message;

sub context () { App::Mobirc->context }

sub describe ($&) {
    my ($name, $code) = @_;

    App::Mobirc->new(
        {
            httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
            global => { keywords => [qw/foo/] }
        }
    );

    $code->();
}

describe 'keyword', sub {
    my $channel = App::Mobirc::Channel->new(
        context, '#test',
    );
    $channel->add_message(
        App::Mobirc::Message->new( body => 'foobar', class => 'public', ) );
    my @log = @{context->get_channel(U "*keyword*")->message_log};
    is scalar(@log), 1;
    is $log[0]->body, 'foobar';
};


describe 'add & get', sub {
    my $channel = App::Mobirc::Channel->new(
        context, U '#test',
    );
    isa_ok context->get_channel(U '#test'), 'App::Mobirc::Channel';
};

describe 'channels', sub {
    my $channel = App::Mobirc::Channel->new(
        context, U '#test',
    );
    my @channels = context->channels;
    use Data::Dumper; warn Dumper(scalar context->channels);
    is scalar(@channels), 1;
    isa_ok $channels[0], 'App::Mobirc::Channel';
};

