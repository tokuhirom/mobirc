use strict;
use warnings;
use Data::Dumper;
use App::Mobirc::Plugin::MessageBodyFilter::IRCColor;

use Test::Base;
eval q{ use String::IRC };
plan skip_all => "String::IRC is not installed." if $@;

filters {
    input => ['eval', 'decorate_irc_color'],
};

sub decorate_irc_color {
    my $x = shift;
    App::Mobirc::Plugin::MessageBodyFilter::IRCColor::process( $x, {} );
}

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: <span style="color:yellow;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')
--- expected: <span style="color:red;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')->bold;
--- expected: <span style="font-weight:bold;color:red;background-color:green;">world</span>

=== inverse is nop.because, html cannot use inverse.
--- input: String::IRC->new('world')->inverse
--- expected: world

===
--- input: String::IRC->new('world')->underline
--- expected: <span style="text-decoration:underline;">world</span>

