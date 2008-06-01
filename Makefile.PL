use inc::Module::Install;
name 'mobirc';
all_from 'lib/App/Mobirc.pm';

license  'gpl';

# moooooose
requires 'Moose'               => '0.48';
requires 'MooseX::Plaggerize'  => '0.03';

# http-engine
requires 'HTTP::Engine'        => '0.0.9';

# poe
requires 'POE'                         => '1.0002';
requires 'POE::Sugar::Args'            => '1.3';
requires 'POE::Component::IRC'         => '5.58';

# mobile stuff
requires 'Encode::JP::Mobile'                       => '0.25';
requires 'HTTP::MobileAgent'                        => '0.27';
requires 'HTTP::MobileAgent::Plugin::Charset'       => '0.03';
requires 'HTML::Entities::ConvertPictogramMobileJp' => '0.06';

# template engine
requires 'Template' => 2.16;                # new 'uri' is supported from 2.16
requires 'Template::Declare'  => '0.28';

# utilities
requires 'Data::Visitor::Encode' => '0.09';
requires 'HTTPx::Dispatcher'  => '0.04';
requires 'Carp'               => '1.04';
requires 'Encode'             => '2.25';
requires 'Exporter'           => '5.62';
requires 'File::Spec'         => '3.2701';
requires 'FindBin'            => '1.47';
requires 'HTML::Entities'     => '1.35';
requires 'HTTP::Response'     => '5.811';
requires 'Path::Class'        => '0.16';
requires 'Proc::Daemon'       => '0.03';
requires 'Params::Validate'   => '0.91';
requires 'Scalar::Util'       => '0.19';
requires 'URI'                => '1.36';
requires 'URI::Find'          => '0.16';
requires 'YAML'               => '0.66';
requires 'UNIVERSAL::require' => '0.11';
requires 'Storable'           => '2.18';
requires 'List::MoreUtils'    => '0.22';
requires 'Module::Find'       => '0.06';

# Note.
#  follow modules are contained by other module.
#  - URI::Escape                 => URI
#  - POE::Filter::HTTPD          => POE
#  - POE::Component::Server::TCP => POE
#  - List::Util                  => Scalar::Util

features(
    'GPS support' => [
        -default => 0,
        recommends('HTTP::MobileAgent::Plugin::Locator'),
        recommends('Template::Plugin::HTMLMobileJp'),
    ],
    'validate configuration file' => [
        recommends('Kwalify', '1.16'),
    ],
    'DoCoMo CSS support' => [
        -default => 1,
        recommends('CSS::Tiny' => '1.15'),
    ],
    'Authorizer::Cookie support' => [
        -default => 0,
        recommends('CGI::Cookie', '1.29'),
    ],
    'DocRoot' => [
        -default => 0,
        recommends('XML::LibXML', '1.66'),
    ],
    'DoCoMoGUID' => [
        -default => 0,
        recommends('HTML::StickyQuery::DoCoMoGUID', '1.66'),
    ],
);

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'Text::Diff';
test_requires 'Test::Exception';
install_script 'mobirc';
use_test_base;
auto_include;
WriteAll;

