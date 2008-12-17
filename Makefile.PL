use inc::Module::Install;
name 'mobirc';
all_from 'lib/App/Mobirc.pm';

license  'gpl';

# Mouse.
requires 'Mouse';

# http-engine
requires 'HTTP::Engine'         => '0.0.19'; # bundled.

# session
requires 'HTTP::Session'        => '0.26';

# poe
requires 'POE'                         => '1.003';
requires 'POE::Sugar::Args'            => '1.3';
requires 'POE::Component::IRC'         => '5.88';

# mobile stuff
requires 'HTTP::MobileAgent'                        => '0.27';

# template engine
requires 'Text::MicroTemplate'  => '0.03';

# utilities
requires 'Exporter'              => '5.62'; # recent version supports "use Exporter 'import'" style
requires 'HTML::Entities'        => '1.35';
requires 'HTML::StickyQuery'     => '0.12';
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
requires 'YAML'                  => '0.66';

features(
    'DoCoMo CSS support' => [
        -default => 1,
        recommends('CSS::Tiny' => '1.15'),
    ],
    'DocRoot' => [
        -default => 0,
        recommends('XML::LibXML', '1.68'),
    ],
    'Irssi' => [
        -default => 0,
        recommends('POE::Session::Irssi', '0.4'),
        recommends('Glib', '0.4'),
        recommends('POE::Loop::Glib', '0.0034'),
    ],
    'Daemonize' => [
        -default => 0,
        recommends('Proc::Daemon'          => '0.03'),
    ]
);

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'Text::Diff';
test_requires 'Test::Exception';
test_requires 'Sub::Uplevel'; # depended by Test::Exception
author_tests('xt');
install_script 'mobirc';
use_test_base;
auto_include;
WriteAll;

