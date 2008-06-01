use strict;
use warnings;
use App::Mobirc::Web::View;
use Test::More tests => 1;
use HTTP::MobileAgent;
use Text::Diff;
use App::Mobirc;
use App::Mobirc::Model::Server;
use App::Mobirc::Util;

# init.
my $c = App::Mobirc->new(
    {
        httpd => { port => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] },
    }
);

my $server = App::Mobirc::Model::Server->new();
$server->get_channel(U '#tester');

my $got = do {
    local $_ = App::Mobirc::Web::View->show(
        'ajax/menu',
        server             => $server,
        keyword_recent_num => 3
    );
    s/^\n//;
    $_;
};

my $expected = do {
    local $_ = <<'...';
<div>
 <div class="keyword_recent_notice">
  <a href="#">Keyword&#40;3&#41;</a>
 </div>
 <div class="channel">
  <a href="#">#tester</a>
 </div>
</div>
...
    s/\n$//;
    $_;
};

ok !diff(\$got, \$expected), diff(\$got, \$expected, { STYLE => "Context" });

