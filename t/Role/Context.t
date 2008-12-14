use t::Utils;
use warnings;
use Test::More tests => 1;
use App::Mobirc;
use Scalar::Util qw/refaddr/;

my $c = App::Mobirc->new(
    config => {
        httpd => { lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] }
    }
);

is refaddr($c), refaddr(App::Mobirc->context);

