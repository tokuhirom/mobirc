package App::Mobirc::Web::C;
use strict;
use warnings;
use Exporter 'import';
use App::Mobirc::Web::View;
use Encode;

our @EXPORT = qw/context server irc_nick render_td/;

sub context  () { App::Mobirc->context } ## no critic
sub server   () { context->server } ## no critic.
sub irc_nick () { POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name } ## no critic

sub render_td {
    my ($c, @args) = @_;
    my $html = App::Mobirc::Web::View->show(@args);
    _set_content_type($c);
    _make_response($c, $html);
}

sub _make_response {
    my ( $c, $out ) = @_;

    ($c, $out) = context->run_hook_filter('html_filter', $c, $out);
    $out = encode( $c->req->mobile_agent->encoding, $out);

    $c->res->body( $out );

    context->run_hook('response_filter', $c);
}

sub _set_content_type {
    my $c = shift;

    my $content_type = do {
        if ( $c->req->mobile_agent->is_docomo ) {
            # docomo phone cannot apply css without this content_type
            'application/xhtml+xml';
        }
        else {
            if ( $c->req->mobile_agent->can_display_utf8 ) {
                'text/html; charset=UTF-8';
            }
            else {
                'text/html; charset=Shift_JIS';
            }
        }
    };

    $c->res->content_type(encode('utf8', $content_type));
}

1;
