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
    App::Mobirc::Plugin::MessageBodyFilter::IRCColor::process( $x, {no_decorate => 1} );
}

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: world

===
--- input: String::IRC->new('world')->red('green')
--- expected: world

