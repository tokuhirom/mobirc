use t::Utils;
use Test::More tests => 1;
use App::Mobirc;
use Scalar::Util qw/refaddr/;

my $c = App::Mobirc->new( config => { } );

is refaddr($c), refaddr(App::Mobirc->context);

