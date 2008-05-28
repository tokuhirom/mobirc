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

use HTTP::Engine;

# TODO: use MobileAttribute...
do {
    my $meta = HTTP::Engine::Request->meta;
    $meta->make_mutable;
    $meta->add_attribute(
        mobile_agent => (
            is      => 'ro',
            isa     => 'Object',
            lazy    => 1,
            default => sub {
                my $self = shift;
                $self->{mobile_agent} = HTTP::MobileAgent->new( $self->headers );
            },
        )
    );
    $meta->make_immutable;
};

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
