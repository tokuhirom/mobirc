use strict;
use warnings;
use boolean ':all';
use Test::More tests => 3;
use Mobirc::HTTPD::Authorizer::Cookie;
use HTTP::Request;
use CGI::Cookie;

my $c = {
    config => {
        httpd => {
            use_cookie => 1,
        }
    },
    req => HTTP::Request->new()
};

is(Mobirc::HTTPD::Authorizer::Cookie->authorize($c) => false, 'fail case');

$c->{req}->header( Cookie => 'passwd=mk; username=pk');

is(Mobirc::HTTPD::Authorizer::Cookie->authorize($c, {username => 'pk', password => 'mk'}) => true, 'success case');
is(Mobirc::HTTPD::Authorizer::Cookie->authorize($c, {username => 'pk', password => 'invalid'}) => false, 'fail case');

