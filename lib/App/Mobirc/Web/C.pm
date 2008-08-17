package App::Mobirc::Web::C;
use strict;
use warnings;
use Exporter 'import';
use App::Mobirc::Web::View;
use Encode;
use Carp ();

our @EXPORT = qw/context server irc_nick render_td/;

sub context  () { App::Mobirc->context } ## no critic
sub server   () { context->server } ## no critic.
sub irc_nick () { POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name } ## no critic

sub render_td {
    my ($req, @args) = @_;
    Carp::croak "invalid arguments for render_td" unless ref $req eq 'HTTP::Engine::Request';

    my $html = sub {
        my $out = App::Mobirc::Web::View->show(@args);
        ($req, $out) = context->run_hook_filter('html_filter', $req, $out);
        $out = encode( $req->mobile_agent->encoding, $out);
    }->();

    my $res = HTTP::Engine::Response->new(
        status       => 200,
        content_type => _content_type($req),
        body         => $html,
    );
    return $res;
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

1;
