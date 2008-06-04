use Test::Base;
use App::Mobirc::Web::Router;
use HTTP::Request;

plan tests => 1*blocks;

filters {
    input    => ['router'],
    expected => [qw/yaml/],
};

run_is_deeply input => 'expected';

sub router {
    my $uri = shift;
    my $req = HTTP::Request->new('GET', $uri);
    App::Mobirc::Web::Router->match($req);
}

__END__

===
--- input: /
--- expected
controller: Root
action: index
args: {}

===
--- input: /mobile/
--- expected
controller: Mobile
action: index
args: {}

===
--- input: /mobile-ajax/
--- expected
controller: MobileAjax
action: index
args: {}

===
--- input: /mobile-ajax/topics
--- expected
controller: MobileAjax
action: topics
args: {}

===
--- input: /mobile/topics
--- expected
controller: Mobile
action: topics
args: {}

===
--- input: /mobile-ajax/recent
--- expected
controller: MobileAjax
action: recent
args: {}

===
--- input: /mobile-ajax/channels?recent=1&channel=%23scon
--- expected
controller: MobileAjax
action: channels
args: {}

