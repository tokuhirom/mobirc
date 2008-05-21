use inc::Module::Install;
name 'mobirc';
all_from 'lib/App/Mobirc.pm';

license  'gpl';

requires 'Moose' => 0.44;
requires 'MooseX::Singleton' => 0.07;
requires 'CGI';
requires 'CGI::Cookie';
requires 'Carp';
requires 'Encode';
requires 'Exporter';
requires 'File::Spec';
requires 'FindBin';
requires 'HTML::Entities';
requires 'HTTP::Response';
requires 'Path::Class';
requires 'POE';
requires 'POE::Component::IRC' => 5.58;
requires 'POE::Component::Server::TCP';
requires 'POE::Filter::HTTPD';
requires 'POE::Sugar::Args';
requires 'Proc::Daemon';
requires 'Scalar::Util';
requires 'List::Util';
requires 'Template' => 2.16; # new 'uri' is supported from 2.16
requires 'URI::Escape';
requires 'URI::Find';
requires 'YAML';
requires 'UNIVERSAL::require';
requires 'Kwalify';
requires 'Storable';
requires 'List::MoreUtils';
requires 'Template::Provider::Encoding';
requires 'HTTP::MobileAgent';
requires 'Class::Accessor';
requires 'CSS::Tiny';
requires 'Encode::JP::Mobile';
requires 'HTTP::MobileAgent::Plugin::Charset';
requires 'HTML::Entities::ConvertPictogramMobileJp';

features(
    'GPS support' => [
        -default => 0,
        recommends('HTTP::MobileAgent::Plugin::Locator'),
        recommends('Template::Plugin::HTMLMobileJp'),
    ],
);

tests 't/*.t t/*/*.t t/*/*/*.t';
build_requires 'Test::More';
build_requires 'Test::Exception';
install_script 'mobirc';
use_test_base;
auto_include;
WriteAll;

