use strict;
use warnings;
use Test::More tests => 9;

use_ok 'Mobirc';
use_ok 'Mobirc::Util';
use_ok 'Mobirc::IRCClient';
use_ok 'Mobirc::HTTPD';
use_ok 'Mobirc::HTTPD::Authorizer::BasicAuth';
use_ok 'Mobirc::HTTPD::Authorizer::Cookie';
use_ok 'Mobirc::HTTPD::Authorizer::EZSubscriberID';
use_ok 'Mobirc::HTTPD::Router';
use_ok 'Mobirc::HTTPD::Controller';
