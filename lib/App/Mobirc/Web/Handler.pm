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
    $c->res($res);
}

sub _handler {
    my $c = shift;
    my $req = $c->req;

    context->run_hook('request_filter', $req);

    if (authorize($req)) {
        process_request($c);
        context->run_hook('response_filter', $c);
        return $c->res;
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

    my $rule = App::Mobirc::Web::Router->match($c->req);

    unless ($rule) {
        # hook by plugins
        if (context->run_hook_first( 'httpd', ( $c, $c->req->uri->path ) ) ) {
            # XXX we should use html filter?
            return;
        }

        # doesn't match.
        do {
            my $uri = $c->req->uri->path;
            warn "dan the 404 not found: $uri" if $uri ne '/favicon.ico';
            # TODO: use $c->res->status(404)
            $c->res->status(404);
            $c->res->body("Dan the 404 not found: $uri");
            return;
        };
    }

    my $controller = "App::Mobirc::Web::C::$rule->{controller}";

    my $meth = $rule->{action};
    my $post_meth = "post_dispatch_$meth";
    my $get_meth  = "dispatch_$meth";
    my $args = $dve->decode( $c->req->mobile_agent->encoding, $rule->{args} );
    if ( $c->req->method =~ /POST/i && $controller->can($post_meth)) {
        return $controller->$post_meth($c, $args);
    } else {
        return $controller->$get_meth($c, $args);
    }
}

1;

