package App::Mobirc::Plugin::Component::HTTPD;
use strict;
use App::Mobirc::Plugin;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;

use HTTP::Engine;
use HTTP::Engine::Middleware;

use Mouse::Util::TypeConstraints;
use JSON ();

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

subtype 'Middlewares',
    as 'ArrayRef';

coerce 'Middlewares',
    from 'Str',
    via { JSON::from_json($_) };

has middlewares => (
    is      => 'ro',
    isa     => 'Middlewares',
    coerce  => 1,
    default => sub { +[] },
);

hook run_component => sub {
    my ( $self, $global_context ) = @_;

    my $request_handler = \&App::Mobirc::Web::Handler::handler;

    my $mw = HTTP::Engine::Middleware->new();
    $mw->install(@{ $self->middlewares });
    $request_handler = $mw->handler( $request_handler );

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
    for my $module (qw/StickyTime HTMLFilter::DoCoMoCSS MessageBodyFilter::IRCColor MessageBodyFilter::Clickable/) {
        my $config = sub {
            for my $p (@{ $global_context->config->{plugin} }) {
                if ($p->{module} eq $module) {
                    return $p->{config};
                }
            }
            return {};
        }->();

        $global_context->load_plugin({
            module => $module,
            config => $config,
        });
    }

    print "running your httpd at http://localhost:@{[ $self->port ]}/\n";
};

no Mouse;
1;
