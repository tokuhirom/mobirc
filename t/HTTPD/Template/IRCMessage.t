use strict;
use warnings;
use App::Mobirc::HTTPD::View;
use App::Mobirc;
use Test::Base;
plan tests => 1*blocks;

local $ENV{TZ} = 'Asia/Tokyo';

my $c = App::Mobirc->new(
    {
        httpd => { port => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] },
        plugin => [
            {
                module => 'App::Mobirc::Plugin::Component::IRCClient',
                config =>
                  { groups => { initialJ => [qw(jknaoya jkondo jagayam)] }, },
            },
        ]
    }
);

filters {
    input => [qw/yaml message render strip/],
    expected => ['strip'],
};

run_is 'input' => 'expected';

sub message {
    my $in = shift;
    App::Mobirc::Model::Message->new( $in );
}

sub render {
    my $msg = shift;
    App::Mobirc::HTTPD::View->show('irc_message', $msg, 'tokuhirom');
}

sub strip {
    s!^\n!!;
    s!\n$!!;
}

__END__

=== SIMPLE
--- input
channel: #test
who    : yappo
body   : YAY<>
time   : 1211726004
class  : public
--- expected
<span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">33</span></span><span class="nick_normal">&#40;yappo&#41;</span><span class="public">YAY&lt;&gt;</span>

=== mine
--- input
channel: #mobirc
class: public
time: 1211726004
who: tokuhirom
body: uh*aww
--- expected
<span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">33</span></span><span class="nick_myself">&#40;tokuhirom&#41;</span><span class="public">uh*aww</span>

=== XSS check
--- input
channel: #mobirc
class: public<
time: 212
who: tokuhirom<
body: uh*aww<
--- expected
<span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span><span class="nick_normal">&#40;tokuhirom&lt;&#41;</span><span class="public&lt;">uh*aww&lt;</span>

=== groups
--- input
channel: #mobirc
class: public
time: 212
who: jagayama
body: uh*aww
--- expected
<span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span><span class="nick_initialJ">&#40;jagayama&#41;</span><span class="public">uh*aww</span>

