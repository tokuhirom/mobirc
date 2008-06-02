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
controller: Mobile
action: index
args: {}

