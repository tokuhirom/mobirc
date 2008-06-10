use strict;
use warnings;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Util;

my $c = App::Mobirc->new(
    {
        httpd => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] },
    }
);

my $server = App::Mobirc::Model::Server->new();
$server->get_channel(U '#tester');

my $got = App::Mobirc::Web::View->show(
    'mobile/topics',
    mobile_agent => HTTP::MobileAgent->new('PC'),
    channels     => scalar($server->channels),
);

my $expected = <<'...';
<?xml version=" 1.0 " encoding="UTF-8"?>
<html lang="ja" xml:lang="ja" xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta http-equiv="Cache-Control" content="max-age=0" />
  <meta name="robots" content="noindex, nofollow" />
  <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
  <link rel="stylesheet" href="/static/mobile.css" type="text/css" />
  <title>topics - mobirc</title>
 </head>
 <body>
  <a name="top"></a>
  <div class="OneTopic">
   <a href="/mobile/channel?channel=I3Rlc3Rlcg">#tester</a>
   <br />
   <span></span>
   <br />
  </div>
  <hr />&#xE6E9;
  <a accesskey="8" href="/mobile/">back to top</a>
 </body>
</html>
...
$expected =~ s/\n$//;

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

