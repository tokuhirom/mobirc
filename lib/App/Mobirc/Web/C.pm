package App::Mobirc::Web::C;
use strict;
use warnings;
use App::Mobirc::Util;
use App::Mobirc::Web::View;
use App::Mobirc::Web::Template;
use Encode;
use Carp ();

sub import {
    my $class = __PACKAGE__;
    my $pkg = caller(0);

    strict->import;
    warnings->import;

    no strict 'refs';
    for my $meth (qw/context server render_irc_message render_td redirect session req param mobile_attribute config/) {
        *{"$pkg\::$meth"} = *{"$class\::$meth"};
    }
}

sub context  () { App::Mobirc->context } ## no critic
sub config   () { context->config } ## no critic
sub server   () { context->server } ## no critic.
sub web_context () { App::Mobirc::Web::Handler->web_context } ## no critic
sub session  () { web_context->session } ## no critic
sub req      () { web_context->req } ## no critic
sub param    ($) { decode_utf8(req->param($_[0])) } ## no critic
sub mobile_attribute () { web_context->mobile_attribute() } ## no critic
sub render_irc_message {
    my $message = shift;
    App::Mobirc->context->mt->render_file(
        "parts/irc_message.mt",
        $message
    )->as_string;
}

sub render_td {
    my @args = @_;
    my $req = req();

    my $html = sub {
        my $out = App::Mobirc::Web::View->show(@args);
        ($req, $out) = context->run_hook_filter('html_filter', $req, $out);
        $out = encode_utf8($out);
    }->();

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => _content_type($req),
        body         => $html,
    );
}

sub _content_type {
    my $req = shift;

    if ( mobile_attribute->is_docomo ) {
        # docomo phone cannot apply css without this content_type
        'application/xhtml+xml; charset=UTF-8';
    }
    else {
        'text/html; charset=UTF-8';
    }
}

# SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
# because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
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
