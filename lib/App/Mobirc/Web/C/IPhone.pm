package App::Mobirc::Web::C::IPhone;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    my ($class, $c) = @_;

    render_td(
        $c,
        'iphone/base' => (
            user_agent => $c->req->user_agent,
            docroot    => (App::Mobirc->context->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_channel {
    my ($class, $c,) = @_;
    my $channel_name = $c->req->params->{channel};

    my $channel = server->get_channel($channel_name);
    render_td(
        $c,
        'iphone/channel' => (
            channel  => $channel,
            irc_nick => irc_nick,
        )
    );
    $channel->clear_unread();
}

sub post_dispatch_channel {
    my ( $class, $c, ) = @_;
    my $channel = $c->req->params->{channel};
    my $message = $c->req->parameters->{'msg'};

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    $c->res->body('ok');
}

sub dispatch_menu {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'iphone/menu' => (
            server             => server,
            keyword_recent_num => server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_keyword {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'iphone/keyword' => {
            logs     => scalar(server->keyword_channel->message_log),
            irc_nick => irc_nick,
        }
    );
    server->keyword_channel->clear_unread();
}

1;
