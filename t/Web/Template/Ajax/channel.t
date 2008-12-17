use t::Utils;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Model::Server;
use App::Mobirc::Util;

local $ENV{TZ} = 'Asia/Tokyo';

# init.
create_global_context();

my $server = App::Mobirc::Model::Server->new();
my $channel = $server->get_channel(U '#tester');
$channel->add_message(
    App::Mobirc::Model::Message->new(
        {
            nick    => 'dankogai',
            body    => 'kogaidan',
            class   => 'public',
            time    => 53252,
        }
    )
);

my $got;
test_he_filter sub {
    $got = do {
        local $_ = App::Mobirc::Web::View->show(
            'Ajax', 'channel', $channel,
        );
        s/^\n//;
        $_;
    };
};

my $expected = do {
    local $_ = <<'...';
<div>
        <span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">47</span></span><span class="public">kogaidan</span>
        <br />
</div>
...
    $_;
};

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

