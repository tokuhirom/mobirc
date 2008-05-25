use strict;
use warnings;
use Test::More tests => 1;
use App::Mobirc;
use Scalar::Util qw/refaddr/;

my $c = App::Mobirc->new(
    {
        httpd => { port => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/], stopwords => [qw/foo31/] }
    }
);

is refaddr($c), refaddr(App::Mobirc->context);

