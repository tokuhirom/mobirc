use strict;
use warnings;
use Test::Base;
use Mobirc::HTTPD::Filter::MailAddress;

plan tests => 1*blocks;

filters {
    input => ['mailaddr' ]
};

sub mailaddr {
    my $x = shift;
    Mobirc::HTTPD::Filter::MailAddress->process( $x, {} );
}

run_is input => 'expected';

__END__

=== basic
--- input: foo bar foo@example.com hoge 
--- expected: foo bar <a href="mailto:foo@example.com" class="mail_address">foo@example.com</a> hoge

