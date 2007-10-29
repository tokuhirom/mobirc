use strict;
use warnings;
use utf8;
use Test::Base;
use Mobirc::HTTPD::Controller;

plan tests => 1*blocks;

sub render_line {
    my $src = shift;
    return Mobirc::HTTPD::Controller::render_line({}, $src);
}

filters {
    input => 'render_line',
};

run_is input => 'expected';

__END__

=== basic
--- input: *public*02:12 Y*ppo__> uh*aww
--- expected: <span class="time"><span class="hour">02</span><span class="colon">:</span><span class="minute">12</span></span> <span class="public">Y*ppo__&gt; uh*aww</span>

=== under score
--- input: *ctcp_action*02:12 Y*ppo__> uh*aww
--- expected: <span class="time"><span class="hour">02</span><span class="colon">:</span><span class="minute">12</span></span> <span class="ctcp_action">Y*ppo__&gt; uh*aww</span>

