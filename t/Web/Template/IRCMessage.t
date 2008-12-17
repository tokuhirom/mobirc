use t::Utils;
use App::Mobirc::Web::View;
use App::Mobirc;
use Test::Base;
plan tests => 1*blocks;

local $ENV{TZ} = 'Asia/Tokyo';

my $c = App::Mobirc->new(
    config => {
        httpd => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] },
        plugin => [
            {
                module => 'Component::IRCClient',
                config => {
                    nick   => 'foo',
                    port   => 3333,
                    server => '127.0.0.1',
                },
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
    my $got;
    hack_irc_nick 'tokuhirom', sub {
        test_he_filter {
            $got = App::Mobirc::Web::View->show('IRCMessage', 'render_irc_message', $msg);
        };
    };
    $got;
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
<span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">33</span></span><span class="nick_normal">(yappo)</span><span class="public">YAY&lt;&gt;</span>

=== mine
--- input
channel: #mobirc
class: public
time: 1211726004
who: tokuhirom
body: uh*aww
--- expected
<span class="time"><span class="hour">23</span><span class="colon">:</span><span class="minute">33</span></span><span class="nick_myself">(tokuhirom)</span><span class="public">uh*aww</span>

=== XSS check
--- input
channel: #mobirc
class: public<
time: 212
who: tokuhirom<
body: uh*aww<
--- expected
<span class="time"><span class="hour">09</span><span class="colon">:</span><span class="minute">03</span></span><span class="nick_normal">(tokuhirom&lt;)</span><span class="public&lt;">uh*aww&lt;</span>

