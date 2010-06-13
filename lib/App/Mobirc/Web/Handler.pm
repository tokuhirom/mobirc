package App::Mobirc::Web::Handler;
use Mouse;
use Scalar::Util qw/blessed/;
use HTTP::Session;
use HTTP::Session::Store::OnMemory;
use HTTP::Session::State::Cookie;
use HTTP::Session::State::URI;
use Module::Find;
use URI::Escape;
use Plack::Response;
use Plack::Request;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::Web::Router;
use App::Mobirc::Web::Context;
useall 'App::Mobirc::Web::C';

my $session_store = HTTP::Session::Store::OnMemory->new(data => {});
if ($ENV{MOBIRC_DEBUG}) {
    require HTTP::Session::Store::DBM;
    $session_store = HTTP::Session::Store::DBM->new(
        file => '/tmp/hoge.dbm'
    );
}

our $CONTEXT;
sub web_context () { $CONTEXT } ## no critic

sub handler {
    my $env = shift;

    global_context->run_hook('env_filter', $env);

    my $req = Plack::Request->new($env);

    my $session = _create_session($req);

    local $CONTEXT = App::Mobirc::Web::Context->new(req => $req, session => $session);
    my $res = _handler($req, $session);
    global_context->run_hook('response_filter', $res);
    $session->response_filter( $res );
    $session->finalize();
    
    DEBUG sprintf("%03d: %s", $res->status, $req->uri->path);
    if (blessed($res)) {
        $res = $res->finalize();
    }
    return $res;
}

sub _handler {
    my ($req, $session) = @_;

    global_context->run_hook('request_filter', $req);

    if ($session->get('authorized')) {
        return process_request_authorized($req, $session);
    } else {
        return process_request_noauth($req, $session);
    }
}

sub _create_session {
    my $req = shift;
    my $conf = global_context->config->{global}->{session};
    my $ma = HTTP::MobileAttribute->new($req->headers);
    HTTP::Session->new(
        store   => $session_store,
        state   => sub {
            if ($ma->is_docomo && $ma->cache_size < 500) {
                # i-mode browser 1.0 does not supports cookie.
                # $ma->cache_size < 500 means 'i-mode browser 1.0'.
                HTTP::Session::State::URI->new(
                    session_id_name => 'sid',
                );
            } else {
                HTTP::Session::State::Cookie->new(
                    name    => 'mobirc_sid',
                    expires => '+1y',
                )
            }
        }->(),
        id      => 'HTTP::Session::ID::MD5',
        request => $req,
    );
}

sub authorize {
    my $req = shift;

    if (global_context->run_hook_first('authorize', $req)) {
        DEBUG "AUTHORIZATION SUCCEEDED";
        return 1; # authorization succeeded.
    } else {
        return 0; # authorization failed
    }
}

sub process_request_authorized {
    my ($req, $session) = @_;

    if (my $rule = App::Mobirc::Web::Router->match($req->path_info)) {
        return do_dispatch($rule, $req, $session);
    } else {
        # hook by plugins
        if (my $res = global_context->run_hook_first( 'httpd', $req )) {
            # XXX we should use html filter?
            return $res;
        }

        # doesn't match.
        return res_404($req);
    }
}

sub process_request_noauth {
    my ($req, $session) = @_;

    if (my $rule = App::Mobirc::Web::Router->match($req->path_info)) {
        if ($rule->{controller} eq 'Account' || $rule->{controller} eq 'Static') {
            return do_dispatch($rule, $req, $session);
        } else {
            return Plack::Response->new(
                302,
                [
                    Location => '/account/login?return=' . uri_escape($req->request_uri)
                ]
            );
        }
    } else {
        return res_404($req);
    }
}

sub do_dispatch {
    my ($rule, $req, $session) = @_;
    my $controller = "App::Mobirc::Web::C::$rule->{controller}";
    my $meth = $rule->{action};
    my $post_meth = "post_dispatch_$meth";
    my $get_meth  = "dispatch_$meth";
    my $args = $rule;
    $args->{session} = $session;
    $CONTEXT->action( $rule->{action} );
    $CONTEXT->controller( $rule->{controller} );
    if ( $req->method =~ /POST/i && $controller->can($post_meth)) {
        return $controller->$post_meth($req, $args);
    } else {
        return $controller->$get_meth($req, $args);
    }
}

sub res_404 {
    my ($req, ) = @_;

    my $uri = $req->path_info;
    warn "dan the 404 not found: $uri\n" if $uri ne '/favicon.ico';
    return Plack::Response->new(
        404,
        ['Content-Type' => 'text/plain'],
        "404 not found: $uri",
    );
}

no Mouse;__PACKAGE__->meta->make_immutable;
1;

