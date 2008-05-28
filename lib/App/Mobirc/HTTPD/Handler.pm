package App::Mobirc::HTTPD::Handler;
use Moose;
use Scalar::Util qw/blessed/;
use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::HTTPD::Router;
use App::Mobirc::HTTPD::C::Mobile;
use App::Mobirc::HTTPD::C::Ajax;
use App::Mobirc::HTTPD::C::Static;

sub handler {
    my $c = shift;
    if (authorize($c)) {
        my $response = process_request($c);
        if ($response && blessed $response && $response->isa('HTTP::Response')) { # TODO: remove this feature
            $c->res->set_http_response($response);
        }
    } else {
        $c->res->status(401);
        $c->res->header('WWW-Authenticate' => qq(Basic Realm="mobirc"));
    }
}

sub authorize {
    my $c = shift;
    for my $code (@{App::Mobirc->context->get_hook_codes('authorize')}) {
        if ($code->($c)) {
            DEBUG "AUTHORIZATION SUCCEEDED";
            return 1; # authorization succeeded.
        }
    }
    return 0; # authorization failed
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

