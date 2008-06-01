package App::Mobirc::HTTPD::Handler;
use Moose;
use Scalar::Util qw/blessed/;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::HTTPD::Router;
use App::Mobirc::HTTPD::C::Mobile;
use App::Mobirc::HTTPD::C::Ajax;
use App::Mobirc::HTTPD::C::Static;
use Data::Visitor::Encode;

my $dve = Data::Visitor::Encode->new;

sub context () { App::Mobirc->context } ## no critic

sub handler {
    my $c = shift;

    context->run_hook('request_filter', $c);

    if (authorize($c)) {
        my $response = process_request($c);
        if ($response && blessed $response && $response->isa('HTTP::Response')) { # TODO: remove this feature
            $c->res->set_http_response($response);
        }
        context->run_hook('response_filter', $c);
    } else {
        $c->res->status(401);
        $c->res->header('WWW-Authenticate' => qq(Basic Realm="mobirc"));
    }
}

sub authorize {
    my $c = shift;

    if (context->run_hook_first('authorize', $c)) {
        DEBUG "AUTHORIZATION SUCCEEDED";
        return 1; # authorization succeeded.
    } else {
        return 0; # authorization failed
    }
}

sub process_request {
    my ($c, ) = @_;

    my $rule = App::Mobirc::HTTPD::Router->match($c->req);

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
            my $response = HTTP::Response->new(404);
            $response->content("Dan the 404 not found: $uri");
            return $response;
        };
    }

    my $controller = "App::Mobirc::HTTPD::C::$rule->{controller}";

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

