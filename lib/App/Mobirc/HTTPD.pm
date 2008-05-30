package App::Mobirc::HTTPD;
use strict;
use warnings;

use POE;
use POE::Filter::HTTPD;
use POE::Component::Server::TCP;

use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Charset;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::HTTPD::Handler;

use HTTP::Engine middlewares => [
    qw/
        +App::Mobirc::HTTPD::Middleware::Encoding
        +App::Mobirc::HTTPD::Middleware::MobileAgent
    /
];

sub init {
    my ( $class, $config, $global_context ) = @_;

    HTTP::Engine->new(
        interface => {
            module => 'POE',
            args => {
                host => ($config->{httpd}->{address} || '0.0.0.0'),
                port => ($config->{httpd}->{port} || 80),
            },
            request_handler => \&App::Mobirc::HTTPD::Handler::handler,
        }
    )->run;
}

1;
