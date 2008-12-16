package App::Mobirc::Plugin::Component::HTTPD;
use strict;
use App::Mobirc::Plugin;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;

use HTTP::Engine;
use App::Mobirc::Web::Middleware::MobileAgent;

use UNIVERSAL::require;

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

has middlewares => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
);

hook run_component => sub {
    my ( $self, $global_context ) = @_;

    my $request_handler = \&App::Mobirc::Web::Handler::handler;
    for my $mw ( @{ $self->middlewares } ) {
      $mw->require or die $@;
      $request_handler = $mw->wrap($request_handler);
    }

    HTTP::Engine->new(
        interface => {
            module => 'POE',
            args   => {
                host  => $self->address,
                port  => $self->port,
                alias => 'mobirc_httpd',
            },
            request_handler => $request_handler,
        }
    )->run;

    # default plugins
    $global_context->load_plugin('StickyTime');
};

no Mouse;
1;
