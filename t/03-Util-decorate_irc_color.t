use strict;
use warnings;
use Data::Dumper;

use Test::Base;
eval q{ use String::IRC };
plan skip_all => "String::IRC is not installed." if $@;
use Mobirc::Util;

filters {
    input => ['eval', 'decorate_irc_color'],
};

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: <span style="font-color:yellow;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')
--- expected: <span style="font-color:red;background-color:green;">world</span>

