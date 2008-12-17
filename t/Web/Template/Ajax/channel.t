use t::Utils;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Model::Server;
use App::Mobirc::Util;

local $ENV{TZ} = 'Asia/Tokyo';

my $channel = server->get_channel(U '#tester');
$channel->add_message(
    App::Mobirc::Model::Message->new(
        {
            who     => 'dankogai',
            body    => 'kogaidan',
            class   => 'public',
            time    => 53252,
        }
    )
);

my $got = test_view('ajax/channel.mt', $channel);

my $expected = do {
    local $_ = <<'...';
<div>

<span class="time">
    <span class="hour">23</span>
    <span class="colon">:</span>
    <span class="minute">47</span>
</span>

<span class="nick_normal">(dankogai)</span>
<span class="public">kogaidan</span>

        <br />
</div>
...
    $_;
};
$expected =~ s/^\s+$//smg;
$got =~ s/^\s+$//smg;

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

