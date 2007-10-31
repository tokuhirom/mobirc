use strict;
use warnings;
use Test::Base;
use Mobirc::HTTPD::Filter::TelephoneNumber;

plan tests => 1*blocks;

filters {
    input => ['mailaddr' ]
};

sub mailaddr {
    my $x = shift;
    Mobirc::HTTPD::Filter::TelephoneNumber->process( $x, {} );
}

run_is input => 'expected';

__END__

=== basic
--- input: foo bar 04-0252-4438 hoge 
--- expected: foo bar <a href="tel:0402524438" class="telephone_number">04-0252-4438</a> hoge

