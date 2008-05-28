package App::Mobirc::HTTPD;
use strict;
use warnings;

use POE;
use POE::Sugar::Args;
use POE::Filter::HTTPD;
use POE::Component::Server::TCP;

use Carp;
use CGI;
use Encode;
use Template;
use File::Spec;
use URI::Find;
use URI::Escape;
use HTTP::Response;
use HTML::Entities;
use Scalar::Util qw/blessed/;
use UNIVERSAL::require;
use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Charset;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::HTTPD::C::Mobile;
use App::Mobirc::HTTPD::C::Ajax;
use App::Mobirc::HTTPD::C::Static;
use App::Mobirc::HTTPD::Router;
use HTTP::Engine;

sub init {
    my ( $class, $config, $global_context ) = @_;

    HTTP::Engine->new(
        interface => {
            module => 'POE',
            args => {
                host => ($config->{httpd}->{address} || '0.0.0.0'),
                port => ($config->{httpd}->{port} || 80),
            },
            request_handler => \&on_web_request,
        }
    )->run;

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
}

sub on_web_request {
    my $c = shift;

    my $request = $c->req->as_http_request();

    my $user_agent = $c->req->user_agent;
#   my $c = {
#       config     => $config,
#       req        => $request,
#       user_agent => $user_agent,
#       mobile_agent => HTTP::MobileAgent->new($user_agent),
#       irc_nick     => POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name,
#       global_context => App::Mobirc->context,
#   };

    # authorization phase
    my $authorized_fg = 0;
    for my $code (@{App::Mobirc->context->get_hook_codes('authorize')}) {
        if ($code->($c)) {
            $authorized_fg++;
            last; # authorization succeeded.
        }
    }

    if ($authorized_fg) {
        my $response = process_request($c);
        if ($response && blessed $response && $response->isa('HTTP::Response')) {
            $c->res->set_http_response($response);
        }
    } else {
        $c->res->status(401);
        $c->res->header('WWW-Authenticate' => qq(Basic Realm="mobirc"));
    }
}

sub process_request {
    my ($c, ) = @_;

    my ($controller, $meth, @args) = App::Mobirc::HTTPD::Router->route($c->req);

    if (blessed $controller && $controller->isa('HTTP::Response')) {
        return $controller;
    }

    $controller = "App::Mobirc::HTTPD::C::$controller";

    my $post_meth = "post_dispatch_$meth";
    my $get_meth  = "dispatch_$meth";
    if ( $c->req->method =~ /POST/i && $controller->can($post_meth)) {
        return $controller->$post_meth($c, @args);
    } else {
        return $controller->$get_meth($c, @args);
    }
}

1;

