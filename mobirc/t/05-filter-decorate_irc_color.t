use strict;
use warnings;
use Data::Dumper;
use Mobirc::HTTPD::Filter::DecorateIRCColor;;

use Test::Base;
eval q{ use String::IRC };
plan skip_all => "String::IRC is not installed." if $@;

filters {
    input => ['eval', 'decorate_irc_color'],
};

sub decorate_irc_color {
    my $x = shift;
    Mobirc::HTTPD::Filter::DecorateIRCColor->process( $x, {} );
}

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: <span style="color:yellow;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')
--- expected: <span style="color:red;background-color:green;">world</span>

