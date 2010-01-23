use t::Utils;
use Test::More tests => 1;

# create 2 channels.
keyword_channel();
test_channel();

describe 'channels', sub {
    my @channels = server->channels;
    is scalar(@channels), 2;
    isa_ok $channels[0], 'App::Mobirc::Model::Channel';

    my $channels = server->channels;
    is ref($channels), 'ARRAY';
    is_deeply $channels, \@channels;
};

