use t::Utils;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;

local $App::Mobirc::VERSION = 0.01;
my $got;
test_he_filter {
    $got = App::Mobirc::Web::View->show(
        'Ajax', 'base' => (
            user_agent => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
            docroot    => '/'
        )
    );
};

my $expected = <<'...';
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <link rel="stylesheet" href="/static/pc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <title>mobirc</title>
        <script src="/static/jquery.js" type="text/javascript"></script>
        <script src="/static/mobirc.js" type="text/javascript"></script>
    </head>
    <body>
        <div id="body">
            <div id="main">
                <div id="menu"></div>
                <div id="contents"></div>
            </div>
            <div id="footer">
                <form onsubmit="send_message(); return false;">
                    <input type="text" id="msg" name="msg" size="30" />
                    <input type="button" value="send" onclick="send_message()" />
                </form>
                <div><span>mobirc - </span><span class="version">0.01</span></div>
            </div>
        </div>

        <script lang="javascript">
            docroot='/';
        </script>
    </body>
</html>
...
$got      =~ s/\n$//;
$expected =~ s/\n$//;

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

