package Mobirc::HTTPD;
use strict;
use warnings;
use boolean ':all';

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

use Mobirc::Util;
use Mobirc::HTTPD::Controller;

our $GLOBAL_CONFIG;                      # TODO: should use HEAP.

sub init {
    my ( $class, $config ) = @_;

    my $session_id = POE::Component::Server::TCP->new(
        Alias        => 'mobirc_httpd',
        Port         => $config->{httpd}->{port},
        ClientFilter => 'POE::Filter::HTTPD',
        ClientInput  => \&on_web_request,
    );

    $GLOBAL_CONFIG = $config;
}

sub on_web_request {
    my $poe        = sweet_args;
    my $request    = $poe->args->[0];
    my $user_agent = $request->{_headers}->{'user-agent'};

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

    my $c = {
        config     => $config,
        poe        => $poe,
        req        => $request,
        user_agent => $user_agent,
        irc_heap   => $poe->kernel->alias_resolve('irc_session')->get_heap,
    };

    # authorization phase
    my $authorized_fg = 0;
    for my $authorizer ( @{ $c->{config}->{httpd}->{authorizer} } ) {
        $authorizer->{module}->use or die $@;

        if ($authorizer->{module}->authorize($c, $authorizer->{config})) {
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

    my ($meth, @args) = route($c, $uri);

    if (blessed $meth && $meth->isa('HTTP::Response')) {
        return $meth;
    }

    if ( $c->{req}->method =~ /POST/i && Mobirc::HTTPD::Controller->can("post_dispatch_$meth")) {
        return Mobirc::HTTPD::Controller->call("post_dispatch_$meth", $c, @args);
    } else {
        return Mobirc::HTTPD::Controller->call("dispatch_$meth", $c, @args);
    }
}

sub route {
    my ($c, $uri) = @_;
    croak 'uri missing' unless $uri;

    if ( $uri eq '/' ) {
        return 'index';
    }
    elsif ( $uri eq '/topics' ) {
        return 'topics';
    }
    elsif ( $uri eq '/recent' ) {
        return 'recent';
    }
    elsif ($uri =~ m{^/channels(-recent)?/([^?]+)(?:\?time=\d+)?$}) {
        my $recent_mode = $1 ? true : false;
        my $channel_name = $2;
        return 'show_channel', $recent_mode, uri_unescape($channel_name);
    } else {
        warn "dan the 404 not found: $uri";
        my $response = HTTP::Response->new(404);
        $response->content("Dan the 404 not found: $uri");
        return $response;
    }
}

1;

