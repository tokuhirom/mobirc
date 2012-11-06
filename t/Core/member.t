use t::Utils;
use Test::More tests => 2;
use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Model::Channel;

my $chan = App::Mobirc::Model::Channel->new(name => '#acotie', server => server());
$chan->join_member("john");
$chan->join_member("manjirou");
is join(',', $chan->members()), 'john,manjirou';
$chan->part_member("john");
is join(',', $chan->members()), 'manjirou';


