package App::Mobirc::Web::Handler;
use Mouse;
use Scalar::Util qw/blessed/;
use HTTP::Session;
use HTTP::Session::Store::OnMemory;
use HTTP::Session::State::Cookie;
use HTTP::Session::State::GUID;
use HTTP::Session::State::MobileAttributeID;
use Module::Find;

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
    my $req = shift;

    my $session = _create_session($req);

    local $CONTEXT = App::Mobirc::Web::Context->new(req => $req, session => $session);
    my $res = _handler($req, $session);
    global_context->run_hook('response_filter', $res);
    $session->response_filter( $res );
    $session->finalize();
    $res;
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
            if ($ma->is_docomo) {
                HTTP::Session::State::GUID->new(
                    mobile_attribute => $ma,
                );
            } elsif ($ma->can('user_id') && $ma->user_id) {
                HTTP::Session::State::MobileAttributeID->new(
                    mobile_attribute => $ma,
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

    if (my $rule = App::Mobirc::Web::Router->match($req)) {
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

    if (my $rule = App::Mobirc::Web::Router->match($req)) {
        if ($rule->{controller} eq 'Account' || $rule->{controller} eq 'Initialize') {
            return do_dispatch($rule, $req, $session);
        } else {
            return HTTP::Engine::Response->new(
                status => 302,
                headers => {
                    Location => '/account/login'
                }
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
    my $args = $rule->{args};
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

    my $uri = $req->uri->path;
    warn "dan the 404 not found: $uri" if $uri ne '/favicon.ico';
    return HTTP::Engine::Response->new(
        status => 404,
        body   => "404 not found: $uri",
    );
}

no Mouse;__PACKAGE__->meta->make_immutable;
1;

