package App::Mobirc::Web::Handler;
use Moose;
use Scalar::Util qw/blessed/;
use Data::Visitor::Encode;
use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Charset;
use Module::Find;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Router;
useall 'App::Mobirc::Web::C';

my $dve = Data::Visitor::Encode->new;

sub context () { App::Mobirc->context } ## no critic

sub handler {
    my $c = shift;

    my $res = _handler($c);
    context->run_hook('response_filter', $res);
    $c->res($res);
}

sub _handler {
    my $c = shift;
    my $req = $c->req;

    context->run_hook('request_filter', $req);

    if (authorize($req)) {
        return process_request($c);
    } else {
        HTTP::Engine::Response->new(
            status => 401,
            headers => HTTP::Headers->new(
                'WWW-Authenticate' => qq{Basic Realm="mobirc"}
            ),
        );
    }
}

sub authorize {
    my $req = shift;

    if (context->run_hook_first('authorize', $req)) {
        DEBUG "AUTHORIZATION SUCCEEDED";
        return 1; # authorization succeeded.
    } else {
        return 0; # authorization failed
    }
}

sub process_request {
    my ($c, ) = @_;
    my $req = $c->req;

    my $rule = App::Mobirc::Web::Router->match($req);

    unless ($rule) {
        # hook by plugins
        if (my $res = context->run_hook_first( 'httpd', $req )) {
            # XXX we should use html filter?
            return $res;
        }

        # doesn't match.
        do {
            my $uri = $req->uri->path;
            warn "dan the 404 not found: $uri" if $uri ne '/favicon.ico';

            return HTTP::Engine::Response->new(
                status => 404,
                body   => "404 not found: $uri",
            );
        };
    }

    my $controller = "App::Mobirc::Web::C::$rule->{controller}";

    my $meth = $rule->{action};
    my $post_meth = "post_dispatch_$meth";
    my $get_meth  = "dispatch_$meth";
    my $args = $dve->decode( $req->mobile_agent->encoding, $rule->{args} );
    if ( $req->method =~ /POST/i && $controller->can($post_meth)) {
        $controller->$post_meth($c, $args);
        return $c->res;
    } else {
        $controller->$get_meth($c, $args);
        return $c->res;
    }
}

1;

