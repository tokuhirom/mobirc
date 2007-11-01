use strict;
use warnings;
use Test::More tests => 16;

use_ok 'Mobirc';
use_ok 'Mobirc::Util';
use_ok 'Mobirc::ConfigLoader';
use_ok 'Mobirc::IRCClient';
use_ok 'Mobirc::HTTPD';
use_ok 'Mobirc::HTTPD::Router';
use_ok 'Mobirc::HTTPD::Controller';

use_ok 'Mobirc::Plugin::Authorizer::BasicAuth';
use_ok 'Mobirc::Plugin::Authorizer::Cookie';
use_ok 'Mobirc::Plugin::Authorizer::EZSubscriberID';
use_ok 'Mobirc::Plugin::Authorizer::SoftbankID';

use_ok 'Mobirc::Plugin::HTMLFilter::DoCoMoCSS';
use_ok 'Mobirc::Plugin::HTMLFilter::CompressHTML';

use_ok 'Mobirc::Plugin::IRCCommand::TiarraLog';

use_ok 'Mobirc::Plugin::MessageBodyFilter::IRCColor';
use_ok 'Mobirc::Plugin::MessageBodyFilter::Clickable';

