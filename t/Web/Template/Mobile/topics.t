use t::Utils;
use lib 'extlib';
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Util;

my $channel = server->get_channel(U '#tester');
$channel->topic('hoge');

my $got;
test_he_filter {
    $got = App::Mobirc::Web::View->show(
        'Mobile', 'topics',
    )
};

my $expected = <<'...';
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobile.css" type="text/css" />
        <title>mobirc</title>
    </head>
    <body>
        <a name="top"></a>
    <div class="OneTopic">
        <a href="/mobile/channel?channel=I3Rlc3Rlcg">#tester</a><br />
        <span>hoge</span><br />
    </div>

<hr />
<div class="GoToTop">
    8 <a accesskey="8" href="/mobile/">ch list</a>
</div>


    </body>
</html>
...

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

