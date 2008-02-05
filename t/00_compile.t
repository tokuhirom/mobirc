use strict;
use warnings;
use Test::More tests => 18;

use_ok 'App::Mobirc';
use_ok 'App::Mobirc::Util';
use_ok 'App::Mobirc::ConfigLoader';
use_ok 'App::Mobirc::Message';
use_ok 'App::Mobirc::Channel';

use_ok 'App::Mobirc::Plugin::Component::IRCClient';

use_ok 'App::Mobirc::HTTPD';
use_ok 'App::Mobirc::HTTPD::Router';
use_ok 'App::Mobirc::HTTPD::Controller';

use_ok 'App::Mobirc::Plugin::Authorizer::BasicAuth';
use_ok 'App::Mobirc::Plugin::Authorizer::Cookie';
use_ok 'App::Mobirc::Plugin::Authorizer::EZSubscriberID';
use_ok 'App::Mobirc::Plugin::Authorizer::SoftBankID';

use_ok 'App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS';
use_ok 'App::Mobirc::Plugin::HTMLFilter::CompressHTML';

use_ok 'App::Mobirc::Plugin::IRCCommand::TiarraLog';

use_ok 'App::Mobirc::Plugin::MessageBodyFilter::IRCColor';
use_ok 'App::Mobirc::Plugin::MessageBodyFilter::Clickable';

