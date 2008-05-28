package App::Mobirc::HTTPD::C::Ajax;
use Moose;
use App::Mobirc::HTTPD::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_ajax_base {
    my ($class, $c) = @_;

    render_td(
        $c,
        'ajax_base' => (
            $c->req->mobile_agent,
            ($c->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_ajax_channel {
    my ($class, $c, $channel_name) = @_;

    my $channel = server->get_channel($channel_name);
    render_td(
        $c,
        'ajax_channel' => (
            $channel,
            irc_nick
        )
    );
    $channel->clear_unread();
}

sub post_dispatch_ajax_channel {
    my ( $class, $c, $channel) = @_;

    my $message = $c->req->parameters->{'msg'};
    $message = decode( $c->req->mobile_agent->encoding, $message );

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    $c->res->body('ok');
}

sub dispatch_ajax_menu {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'ajax_menu' => (
            server,
            server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_ajax_keyword {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'ajax_keyword' => (
            server,
            irc_nick,
        )
    );
    server->keyword_channel->clear_unread();
}

1;
