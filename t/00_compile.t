use t::Utils;
use warnings;
use t::Utils;
use Test::More tests => 12;

use_ok 'App::Mobirc';
use_ok 'App::Mobirc::Util';
use_ok 'App::Mobirc::ConfigLoader';
use_ok 'App::Mobirc::Model::Message';
use_ok 'App::Mobirc::Model::Channel';

use_ok 'App::Mobirc::Plugin::Component::IRCClient';

use_ok 'App::Mobirc::Plugin::Component::HTTPD';
use_ok 'App::Mobirc::Web::Router';

use_ok 'App::Mobirc::Plugin::HTMLFilter::CompressHTML';

use_ok 'App::Mobirc::Plugin::IRCCommand::TiarraLog';

use_ok 'App::Mobirc::Plugin::MessageBodyFilter::IRCColor';
use_ok 'App::Mobirc::Plugin::MessageBodyFilter::Clickable';

