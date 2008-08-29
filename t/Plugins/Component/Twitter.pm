use strict;
use warnings;
use Test::More;
eval "use POE::Component::Client::Twitter";
plan skip_all => "this tests requires PoCo::C::Twitter" if $@;
plan tests => 1;

use_ok 'App::Mobirc::Plugin::Component::Twitter';

