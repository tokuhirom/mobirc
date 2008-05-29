package App::Mobirc::HTTPD::C::Ajax;
use Moose;
use App::Mobirc::HTTPD::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    my ($class, $c) = @_;

    render_td(
        $c,
        'ajax/base' => (
            $c->req->mobile_agent,
            ($c->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_channel {
    my ($class, $c, $channel_name) = @_;

    my $channel = server->get_channel($channel_name);
    render_td(
        $c,
        'ajax/channel' => (
            $channel,
            irc_nick
        )
    );
    $channel->clear_unread();
}

sub post_dispatch_channel {
    my ( $class, $c, $channel) = @_;

    my $message = $c->req->parameters->{'msg'};
    $message = decode( $c->req->mobile_agent->encoding, $message );

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    $c->res->body('ok');
}

sub dispatch_menu {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'ajax/menu' => (
            server,
            server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_keyword {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'ajax/keyword' => {
            logs     => scalar(server->keyword_channel->message_log),
            irc_nick => irc_nick,
        }
    );
    server->keyword_channel->clear_unread();
}

1;
