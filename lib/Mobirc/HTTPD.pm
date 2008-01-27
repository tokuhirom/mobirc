package Mobirc::HTTPD;
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

use Mobirc;
use Mobirc::Util;
use Mobirc::HTTPD::Controller;
use Mobirc::HTTPD::Router;

our $GLOBAL_CONFIG;                      # TODO: should use HEAP.

sub init {
    my ( $class, $config, $global_context ) = @_;

    my $session_id = POE::Component::Server::TCP->new(
        Alias        => 'mobirc_httpd',
        Address      =>($config->{httpd}->{address} || '0.0.0.0'),
        Port         => $config->{httpd}->{port},
        ClientFilter => 'POE::Filter::HTTPD',
        ClientInput  => \&on_web_request,
        Error        => sub {
            die( "$$: " . 'Server ',
                $_[SESSION]->ID, " got $_[ARG0] error $_[ARG1] ($_[ARG2])\n" );
        }
    );

    $GLOBAL_CONFIG = $config;
}

sub on_web_request {
    my $poe        = sweet_args;
    my $request    = $poe->args->[0];

    my $config = $GLOBAL_CONFIG or die "config missing";

    if ( $ENV{DEBUG} ) {
        require Module::Reload;
        Module::Reload->check;
    }

    # Filter::HTTPD sometimes generates HTTP::Response objects.
    # They indicate (and contain the response for) errors that occur
    # while parsing the client's HTTP request.  It's easiest to send
    # the responses as they are and finish up.
    if ( $request->isa('HTTP::Response') ) {
        $poe->heap->{client}->put($request);
        $poe->kernel->yield('shutdown');
        return;
    }

    my $user_agent = $request->{_headers}->{'user-agent'};
    my $c = {
        config     => $config,
        req        => $request,
        user_agent => $user_agent,
        mobile_agent => HTTP::MobileAgent->new($user_agent),
        irc_nick     => $poe->kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name,
        global_context => Mobirc->context,
    };

    # authorization phase
    my $authorized_fg = 0;
    for my $code (@{$c->{global_context}->get_hook_codes('authorize')}) {
        if ($code->($c)) {
            $authorized_fg++;
            last; # authorization succeeded.
        }
    }

    if ($authorized_fg) {
        my $response = process_request($c, $request->uri);
        $poe->heap->{client}->put($response);
        $poe->kernel->yield('shutdown');
    } else {
        my $response = HTTP::Response->new(401);
        $response->push_header(
            WWW_Authenticate => qq(Basic Realm="mobirc") );
        $response->content( "authorization required" );
        $poe->heap->{client}->put($response);
        $poe->kernel->yield('shutdown');
        return;
    }
}

sub process_request {
    my ($c, $uri) = @_;
    croak 'uri missing' unless $uri;

    my ($meth, @args) = Mobirc::HTTPD::Router->route($c, $uri);

    if (blessed $meth && $meth->isa('HTTP::Response')) {
        return $meth;
    }

    if ( $c->{req}->method =~ /POST/i && Mobirc::HTTPD::Controller->can("post_dispatch_$meth")) {
        return Mobirc::HTTPD::Controller->call("post_dispatch_$meth", $c, @args);
    } else {
        return Mobirc::HTTPD::Controller->call("dispatch_$meth", $c, @args);
    }
}

1;

