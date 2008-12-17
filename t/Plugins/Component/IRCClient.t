use t::Utils;
use POE;
use App::Mobirc::Plugin::Component::IRCClient;
use App::Mobirc;
use Test::More;
use Data::Dumper;
use POE::Sugar::Args;
use App::Mobirc::Util;
use Encode;
eval q{use POE::Component::Server::IRC;};
plan skip_all => "POE::Component::Server::IRC is not installed." if $@;
plan tests => 6;

my $PORT = 9999;

$SIG{INT} = sub { die };

my $global_context = global_context();
$global_context->load_plugin(
    {
        module => 'Component::IRCClient',
        config => {
            nick     => 'testee',
            port     => $PORT,
            incode   => 'utf8',
            username => 'test man',
            desc     => 'hoge',
            server   => 'localhost',
        },
    }
);
$global_context->run_hook('run_component');
POE::Session->create(
    package_states => [
        main => [qw/_start test/],
    ],
);
$poe_kernel->run;
exit 0;

sub _start {
    my ($kernel, $heap) = @_[ KERNEL, HEAP ];

    $kernel->yield('test');
}

sub test {
    my ($kernel, $heap) = @_[ KERNEL, HEAP ];

    my $context = global_context();

    my $tasks_for = {
        '#coderepos' => [
            {input => [ qw/irc_join tester/,  '#coderepos' ], expected => 'tester joined'},
            {input => [ qw/irc_public  tester/,  ['#coderepos'], 'publictest' ], expected => 'publictest'},
            {input => [ qw/irc_notice tester/, ['#coderepos'], qw/noticetest/ ], expected => 'noticetest'},
            {input => [ qw/irc_ctcp_action tester/, ['#coderepos'], 'MYACTION' ], expected => '* tester MYACTION'},
            {input => [ qw/irc_kick OppaiSan/,  '#coderepos', qw/knagano DNBK/ ], expected => 'OppaiSan has kicked knagano(DNBK)'},
            {input => [ qw/irc_part tester/, '#coderepos', qw/PARTMESSAGE/ ], expected => 'tester leaves(PARTMESSAGE)'},
        ],
        '#topic' => [
            {input => [ qw/irc_join tester/, '#topic' ], expected => 'tester joined'},
            {input => [ qw/irc_topic  tester/, '#topic', 'THISISTOPIC' ], expected => 'tester set topic: THISISTOPIC'},
        ],
        '#topicraw' => [
            {input => [ qw/irc_join tester/, '#topicraw' ], expected => 'tester joined'},
            {input => [ qw/irc_332 tester/, '#topicraw', ['#topicraw', 'TOPICRAW' ] ], expected => undef},
        ],
        '*server*' => [
            {input => [ qw/irc_001/ ], expected => 'Connected to irc server!'},
            {input => [ qw/irc_snotice SNOTICEMESSAGE/ ], expected => 'SNOTICEMESSAGE'},
            {input => [ qw/irc_disconnected/], expected => 'Disconnected from irc server, trying to reconnect...'},
        ],
    };

    while (my ($channel, $tasks) = each %$tasks_for) {
        for my $task (@$tasks) {
            $kernel->call(irc_session => @{$task->{input}});
        }
    }

    while ( my ( $channel, $tasks ) = each %$tasks_for ) {
        is(
            join(
                "\n",
                map { $_->body } @{
                    $context->get_channel( decode( 'utf8', $channel ) )
                      ->message_log
                  }
            ),
            join( "\n", grep { defined $_ } map { $_->{expected} } @$tasks ),
            "CHECK $channel"
        );
    }

    is $context->get_channel(decode('utf8', '#topic'))->topic, 'THISISTOPIC', 'topic set';
    is $context->get_channel(decode('utf8', '#topicraw'))->topic, 'TOPICRAW', 'topicraw set';

    exit 0;
}

