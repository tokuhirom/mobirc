package App::Mobirc::Plugin::Component::HTTPD;
use strict;
use MooseX::Plaggerize::Plugin;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;

use HTTP::Engine;
use App::Mobirc::Web::Middleware::Encoding;
use App::Mobirc::Web::Middleware::MobileAgent;

has address => (
    is      => 'ro',
    isa     => 'Str',
    default => '0.0.0.0',
);

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 80,
);

hook run_component => sub {
    my ( $self, $global_context ) = @_;

    HTTP::Engine->new(
        interface => {
            module => 'POE',
            args   => {
                host  => $self->address,
                port  => $self->port,
                alias => 'mobirc_httpd',
            },
            request_handler => App::Mobirc::Web::Middleware::Encoding->wrap( \&App::Mobirc::Web::Handler::handler ),
        }
    )->run;

    # default plugins
    $global_context->load_plugin('StickyTime');
};

1;
