use strict;
use warnings;
use Test::More tests => 2;
use Encode;
use App::Mobirc;
use App::Mobirc::Channel;
use App::Mobirc::Message;

my $global_context = App::Mobirc->new(
    {
        httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);

my $channel = App::Mobirc::Channel->new(
    $global_context, '#test',
);
$channel->add_message(
    App::Mobirc::Message->new( body => 'foobar', class => 'public', ) );
my @log = @{$global_context->get_channel(decode_utf8 "*keyword*")->message_log};
is scalar(@log), 1;
is $log[0]->body, 'foobar';

