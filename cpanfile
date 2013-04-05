requires 'Any::Moose', '0.13';
requires 'AnyEvent', '5.271';
requires 'AnyEvent::IRC', '0.95';
requires 'CSS::Tiny', '1.15';
requires 'Config::Tiny', '2.12';
requires 'Data::OptList', '0.105';
requires 'Data::Recursive::Encode';
requires 'Exporter', '5.62';
requires 'HTML::Entities', '1.35';
requires 'HTML::StickyQuery', '0.12';
requires 'HTTP::MobileAttribute', '0.21';
requires 'HTTP::Session', '0.44';
requires 'JSON', '2.09';
requires 'JavaScript::Value::Escape';
requires 'List::MoreUtils', '0.22';
requires 'MIME::Base64::URLSafe', '0.01';
requires 'Module::Find', '0.06';
requires 'Mouse', '0.6';
requires 'MouseX::Types', '0.05';
requires 'Params::Util';
requires 'Params::Validate', '0.91';
requires 'Path::Class', '0.19';
requires 'Plack', '0.9938';
requires 'Plack::Middleware::ReverseProxy', '0.14';
requires 'Plack::Request', '0.09';
requires 'Router::Simple', '0.05';
requires 'String::CamelCase', '0.01';
requires 'String::IRC', '0.04';
requires 'Tatsumaki', '0.101';
requires 'Text::MicroTemplate', '0.13';
requires 'Text::VisualWidth::PP', '0.01';
requires 'Twiggy', '0.1005';
requires 'UNIVERSAL::require', '0.11';
requires 'URI', '1.36';
requires 'URI::Find', '20100505';
requires 'YAML', '0.68';
requires 'parent', '0.223';
requires 'perl', '5.01';

# irssi
recommends 'POE::Session::Irssi', '0.4';
recommends 'Glib',                '0.4';
recommends 'POE::Loop::Glib',     '0.0034';

on test => sub {
    requires 'Test::Base::Less';
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
    requires 'Text::Diff';

    recommends 'HTML::TreeBuilder::XPath';
    recommends 'POE::Component::Server::IRC';
    recommends 'Text::VisualWidth::UTF8';
    recommends 'Test::LongString';
};
