use strict;
use Module::Build;

my $builder = Module::Build->new(
    dist_name      => 'mobirc',
    license        => 'perl',
    dist_version_from => 'lib/App/Mobirc.pm',
    dynamic_config => 0,
    configure_requires => { 'Module::Build' => 0.40 },
    build_requires => {
        'Test::More'       => 0.98,
        'Text::Diff'       => 0,
        'Test::Requires'   => 0,
        'Test::Base::Less' => 0,
        (
            $ENV{TRAVIS} ? (
                'HTML::TreeBuilder::XPath' => 0,
                'POE::Component::Server::IRC' => 0,
                'Text::VisualWidth::UTF8' => 0,
                'Test::LongString' => 0,
            ) : ()
        )
    },
    requires => {
        perl => 5.008001,

        # AnyEvent
        'AnyEvent'      => 5.271,
        'AnyEvent::IRC' => 0.95,

        # Plack
        'Plack'                           => 0.9938,
        'Twiggy'                          => 0.1005,
        'Plack::Request'                  => 0.09,
        'Plack::Middleware::ReverseProxy' => 0.14,
        'Tatsumaki'                       => 0.1010,

        # Mouse.
        'Mouse'         => 0.60,
        'MouseX::Types' => 0.05,
        'Any::Moose'    => 0.13,

        # session
        'HTTP::Session' => '0.44',

        # mobile stuff
        'HTTP::MobileAttribute' => '0.21',

        # template engine
        'Text::MicroTemplate' => '0.13',

        # utilities
        'parent'            => 0.223,
        'Config::Tiny'      => 2.12,
        'String::CamelCase' => '0.01',
        'Exporter' =>
          '5.62',    # recent version supports "use Exporter 'import'" style
        'HTML::Entities'        => '1.35',
        'HTML::StickyQuery'     => '0.12',
        'Router::Simple'        => '0.05',
        'JSON'                  => '2.09',
        'List::MoreUtils'       => '0.22',
        'MIME::Base64::URLSafe' => '0.01',
        'Module::Find'          => '0.06',
        'Params::Validate'      => '0.91',
        'Path::Class'           => '0.19',
        'UNIVERSAL::require'    => '0.11',
        'URI'                   => '1.36',
        'URI::Find'             => '20100505',
        'YAML'                  => '0.68',
        'String::IRC'           => '0.04',
        'CSS::Tiny'             => '1.15',
        'Data::OptList'         => '0.105',
        'Params::Util' => 0,    # for Data::OptList
        'Data::Recursive::Encode' => 0,
        'Text::VisualWidth::PP'     => 0.01,
        'JavaScript::Value::Escape' => 0,
    },
    auto_features => {
        'irssi support' => {
            description => 'irrsi support',
            requires    => {
                'POE::Session::Irssi', '0.4',
                'Glib',                '0.4',
                'POE::Loop::Glib',     '0.0034',
            },
        },
    },
    script_files => ['mobirc'],
    test_files   => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',
    recursive_test_files => 1,
    create_readme        => 1,
    create_license       => 1,
);
$builder->feature('irssi support' => 0);
$builder->create_build_script();

# ~/perl5/perlbrew/perls/perl-5.8.1/bin/perl -I extlib/lib/perl5/ tools/cpanm -nv -L extlib --installdeps .

