package App::Mobirc::Web::C;
use strict;
use warnings;
use App::Mobirc::Web::View;
use Encode;
use Carp ();

sub import {
    my $class = __PACKAGE__;
    my $pkg = caller(0);

    strict->import;
    warnings->import;

    no strict 'refs';
    for my $meth (qw/context server irc_nick render_td redirect session req param/) {
        *{"$pkg\::$meth"} = *{"$class\::$meth"};
    }
}

sub context  () { App::Mobirc->context } ## no critic
sub server   () { context->server } ## no critic.
sub irc_nick () { POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name } ## no critic
sub web_context () { App::Mobirc::Web::Handler->web_context } ## no critic
sub session  () { web_context->session } ## no critic
sub req      () { web_context->req } ## no critic
sub param    ($) { req->param($_[0]) } ## no critic
sub mobile_attribute () { web_context->mobile_attribute($_[0]) } ## no critic

sub render_td {
    my @args = @_;
    my $req = req();

    my $html = sub {
        my $out = App::Mobirc::Web::View->show(@args);
        ($req, $out) = context->run_hook_filter('html_filter', $req, $out);
        $out = encode( $req->mobile_agent->encoding, $out);
    }->();

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => _content_type($req),
        body         => $html,
    );
}

sub _content_type {
    my $req = shift;

    if ( $req->mobile_agent->is_docomo ) {
        # docomo phone cannot apply css without this content_type
        'application/xhtml+xml; charset=UTF-8';
    }
    else {
        if ( $req->mobile_agent->can_display_utf8 ) {
            'text/html; charset=UTF-8';
        }
        else {
            'text/html; charset=Shift_JIS';
        }
    }
}

sub redirect {
    my $path = shift;
    HTTP::Engine::Response->new(
        status => 302,
        headers => {
            Location => $path
        },
    );
}

1;
