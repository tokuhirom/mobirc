use strict;
use warnings;
use utf8;
use Test::Base;
use Mobirc::HTTPD::Controller;
use Mobirc;

plan tests => 1*blocks;

{
    package PoCoIRCMock;
    sub nick_name { 'tokuhirom' }
}

sub render_line {
    my $src = shift;
    my $irc = bless {}, 'PoCoIRCMock';
    my $global_context = Mobirc->new(
        {
            irc => {
                nick     => 'foo',
                port     => 52522,
                incode   => 'utf8',
                username => 'foo',
                desc     => 'foo',
                server   => 'bar'
            },
            httpd => { port => 80 }
        }
    );
    return Mobirc::HTTPD::Controller::render_line({irc_heap => {irc => $irc }, global_context => $global_context}, $src);
}

filters {
    input => ['yaml', 'render_line'],
};

run_is input => 'expected';

__END__

=== basic
--- input
channel: #mobirc
class: public
time: 212
who: Y*ppo__
msg: uh*aww
--- expected: <span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span> <span class='nick_normal'>(Y*ppo__)</span> <span class="public">uh*aww</span>

=== mine
--- input
channel: #mobirc
class: public
time: 212
who: tokuhirom
msg: uh*aww
--- expected: <span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span> <span class='nick_myself'>(tokuhirom)</span> <span class="public">uh*aww</span>

=== XSS check
--- input
channel: #mobirc
class: public<
time: 212
who: tokuhirom<
msg: uh*aww<
--- expected: <span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span> <span class='nick_normal'>(tokuhirom&lt;)</span> <span class="public&lt;">uh*aww&lt;</span>
