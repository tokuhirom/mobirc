package App::Mobirc::HTTPD::C;
use strict;
use warnings;
use Exporter 'import';
use App::Mobirc::HTTPD::View;
use Encode;

our @EXPORT = qw/context server irc_nick render_td/;

sub context  () { App::Mobirc->context } ## no critic
sub server   () { context->server } ## no critic.
sub irc_nick () { POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name } ## no critic

sub render_td {
    my ($c, @args) = @_;
    my $html = App::Mobirc::HTTPD::View->show(@args);
    _make_response($c, $html);
}

sub _make_response {
    my ( $c, $out ) = @_;

    $out = _html_filter($c, $out);
    my $content = encode( $c->req->mobile_agent->encoding, $out);

    # change content type for docomo
    # FIXME: hmm... should be in the plugin?
    my $content_type = context->config->{httpd}->{content_type};
    $content_type= 'application/xhtml+xml' if $c->req->mobile_agent->is_docomo;
    unless ( $content_type ) {
        if ( $c->req->mobile_agent->can_display_utf8 ) {
            $content_type = 'text/html; charset=UTF-8';
        } else {
            $content_type = 'text/html; charset=Shift_JIS';
        }
    }

    $c->res->content_type(encode('utf8', $content_type));
    $c->res->body( $content );

    for my $code (@{context->get_hook_codes('response_filter')}) {
        $code->($c);
    }
}

sub _html_filter {
    my $c = shift;
    my $content = shift;

    for my $code (@{context->get_hook_codes('html_filter')}) {
        $content = $code->($c, $content);
    }

    $content;
}


1;
