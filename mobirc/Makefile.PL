use inc::Module::Install;
name 'mobirc';
all_from 'lib/Mobirc.pm';

requires 'CGI';
requires 'Carp';
requires 'Encode';
requires 'Exporter';
requires 'File::Spec';
requires 'FindBin';
requires 'HTML::Entities';
requires 'HTTP::Response';
requires 'POE';
requires 'POE::Component::IRC';
requires 'POE::Component::Server::TCP';
requires 'POE::Filter::HTTPD';
requires 'POE::Sugar::Args';
requires 'Scalar::Util';
requires 'List::Util';
requires 'Template';
requires 'URI::Escape';
requires 'URI::Find';
requires 'YAML::Syck';
requires 'boolean';
requires 'utf8';
requires 'UNIVERSAL::require';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;

