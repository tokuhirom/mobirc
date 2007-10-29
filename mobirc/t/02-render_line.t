use strict;
use warnings;
use utf8;
use Test::Base;
use Mobirc::HTTPD::Controller;

plan tests => 1*blocks;

{
    package PoCoIRCMock;
    sub nick_name { 'tokuhirom' }
}

sub render_line {
    my $src = shift;
    my $irc = bless {}, 'PoCoIRCMock';
    return Mobirc::HTTPD::Controller::render_line({irc_heap => {irc => $irc }}, $src);
}

filters {
    input => 'render_line',
};

run_is input => 'expected';

__END__

=== basic
--- input: *public*02:12 Y*ppo__> uh*aww
--- expected: <span class="time"><span class="hour">02</span><span class="colon">:</span><span class="minute">12</span></span> <span class="public"><span class='nick_normal'>Y*ppo__</span>&gt; uh*aww</span>

=== mine
--- input: *public*02:12 tokuhirom> uh*aww
--- expected: <span class="time"><span class="hour">02</span><span class="colon">:</span><span class="minute">12</span></span> <span class="public"><span class='nick_myself'>tokuhirom</span>&gt; uh*aww</span>

=== under score
--- input: *ctcp_action*02:12 Y*ppo__> uh*aww
--- expected: <span class="time"><span class="hour">02</span><span class="colon">:</span><span class="minute">12</span></span> <span class="ctcp_action">Y*ppo__&gt; uh*aww</span>

