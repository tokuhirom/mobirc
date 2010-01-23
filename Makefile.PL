use inc::Module::Install;
name 'mobirc';
all_from 'lib/App/Mobirc.pm';

license  'gpl';

# AnyEvent
requires 'AnyEvent' => 5.24;
requires 'AnyEvent::IRC' => 0.95;

# Plack
requires 'Plack'                           => 0.9031;
requires 'Plack::Server::AnyEvent'         => 0.03;
requires 'Plack::Request'                  => 0.09;
requires 'Plack::Middleware::ReverseProxy' => 0.04;

# Mouse.
requires 'Mouse'         => 0.47;
requires 'MouseX::Types' => 0.04;
requires 'Any::Moose'    => 0.11;

# session
requires 'HTTP::Session' => '0.29';

# mobile stuff
requires 'HTTP::MobileAttribute' => '0.13';

# template engine
requires 'Text::MicroTemplate' => '0.05';

# utilities
requires 'Config::Tiny'      => 2.12;
requires 'String::CamelCase' => '0.01';
requires 'Exporter' => '5.62';    # recent version supports "use Exporter 'import'" style
requires 'HTML::Entities'        => '1.35';
requires 'HTML::StickyQuery'     => '0.12';
requires 'HTML::StickyQuery::DoCoMoGUID'    => '0.01';
requires 'HTTPx::Dispatcher'     => '0.04';
requires 'JSON'                  => '2.09';
requires 'List::MoreUtils'       => '0.22';
requires 'MIME::Base64::URLSafe' => '0.01';
requires 'Module::Find'          => '0.06';
requires 'Params::Validate'      => '0.91';
requires 'Path::Class'           => '0.16';
requires 'UNIVERSAL::require'    => '0.11';
requires 'URI'                   => '1.36';
requires 'URI::Find'             => '0.16';
requires 'YAML'                  => '0.68';
requires 'String::IRC'           => '0.01';
requires 'CSS::Tiny'             => '1.15';
requires 'Data::OptList'         => '0.105';

features(
    'Irssi' => [
        -default => 0,
        recommends('POE::Session::Irssi', '0.4'),
        recommends('Glib', '0.4'),
        recommends('POE::Loop::Glib', '0.0034'),
    ],
    'Android' => [
        -default => 0,
        recommends('Text::VisualWidth::UTF8' => '0.02'),
    ],
);

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
requires 'Test::More' => 0.94;
test_requires 'Test::More';
test_requires 'Text::Diff';
author_tests('xt');
install_script 'mobirc';
use_test_base;
auto_include;
WriteAll;

