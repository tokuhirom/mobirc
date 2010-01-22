package App::Mobirc::Plugin::Component::HTTPD;
use strict;
use App::Mobirc::Plugin;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;

use Plack;
use Plack::Loader;
use Plack::Middleware::ReverseProxy;

use Data::OptList;

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

    my $app = \&App::Mobirc::Web::Handler::handler;
    my $middlewares = Data::OptList::mkopt($self->middlewares);
    while (my ($module, $conf) = splice @$middlewares, 0, 2) {
        $module = Plack::Util::load_class($module, 'Plack::Middleware');
        $app = $module->wrap($app, %$conf);
    }

    Plack::Loader->load(
        'AnyEvent',
        port => $self->port,
        host => $self->address
    )->run($app);

    print "running your httpd at http://localhost:@{[ $self->port ]}/\n";
};

no Mouse;
1;
