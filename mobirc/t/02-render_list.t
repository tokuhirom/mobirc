use strict;
use warnings;
use utf8;
use Test::Base;
use Mobirc::HTTPD::Controller;

plan tests => 1*blocks;

sub render_list {
    my $src = shift;
    return Mobirc::HTTPD::Controller::render_list({}, $src);
}

filters {
    input => 'render_list',
};

run_is input => 'expected';

__END__

===
--- input
hohoge
--- expected chomp
hohoge

===
--- input
*public*02:12 Y*ppo__> uh*aww
--- expected
<span class="public">02:12 Y*ppo__&gt; uh*aww</span><br />

===
--- input
*public*02:12 Y*ppo__> uh*aww
*notice*02:14 hir*se31> w
--- expected
<span class="notice">02:14 hir*se31&gt; w</span><br />
<span class="public">02:12 Y*ppo__&gt; uh*aww</span><br />

