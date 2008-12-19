package App::Mobirc::Plugin::Component::HTTPD;
use strict;
use App::Mobirc::Plugin;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;

use HTTP::Engine;

use UNIVERSAL::require;

has address => (
    is      => 'ro',
    isa     => 'Str',
    default => '0.0.0.0',
);

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 5678,
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

    print "running your httpd at http://localhost:@{[ $self->port ]}/\n";
};

no Mouse;
1;
