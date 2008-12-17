use t::Utils;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Model::Server;
use App::Mobirc::Util;

# init.
create_global_context();

my $channel = server->get_channel(U '#tester');
$channel->add_message(
    App::Mobirc::Model::Message->new(
        channel => '#tester',
        who     => 'hoge',
        body    => 'foo',
        class   => 'public',
        time    => time(),
    )
);

my $got = test_view('ajax/menu.mt');

my $expected = do {
    local $_ = <<'...';
<div>
    <div class="keyword_recent_notice">
        <a href="#">Keyword(1)</a>
    </div>

    <div class="unread channel">
        <a href="#">#tester</a>
    </div>
    <div class="unread channel">
        <a href="#">*keyword*</a>
    </div>

</div>
...
    $_;
};

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

