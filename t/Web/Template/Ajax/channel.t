use strict;
use warnings;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Model::Server;
use App::Mobirc::Util;

local $ENV{TZ} = 'Asia/Tokyo';

# init.
my $c = App::Mobirc->new(
    {
        httpd => { lines => 40 },
        global => {},
    }
);

my $server = App::Mobirc::Model::Server->new();
my $channel = $server->get_channel(U '#tester');
$channel->add_message(
    App::Mobirc::Model::Message->new(
        {
            nick    => 'dankogai',
            message => 'kogaidan',
            class   => 'public',
            time    => 53252,
        }
    )
);

my $got = do {
    local $_ = App::Mobirc::Web::View->show(
        'ajax/channel',
        channel  => $channel,
        irc_nick => 'tokuhirom'
    );
    s/^\n//;
    $_;
};

my $expected = do {
    local $_ = <<'...';
<div><span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">47</span></span><span class="public"></span>
 <br />
</div>
...
    s/\n$//;
    $_;
};

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

