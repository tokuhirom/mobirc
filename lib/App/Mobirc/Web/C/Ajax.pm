package App::Mobirc::Web::C::Ajax;
use Mouse;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    my ($class, $req) = @_;

    render_td(
        $req,
        'ajax/base' => (
            user_agent => $req->user_agent,
            docroot    => (App::Mobirc->context->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_channel {
    my ($class, $req,) = @_;
    my $channel_name = $req->params->{channel};

    my $channel = server->get_channel($channel_name);
    my $res = render_td(
        $req,
        'ajax/channel' => (
            channel  => $channel,
            irc_nick => irc_nick,
        )
    );
    $channel->clear_unread();
    return $res;
}

sub post_dispatch_channel {
    my ( $class, $req, ) = @_;
    my $channel = $req->params->{channel};
    my $message = $req->parameters->{'msg'};

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain',
        body         => 'ok',
    );
}

sub dispatch_menu {
    my ($class, $req) = @_;

    render_td(
        $req,
        'ajax/menu' => (
            server             => server,
            keyword_recent_num => server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_keyword {
    my ($class, $req ) = @_;

    my $res = render_td(
        $req,
        'ajax/keyword' => {
            logs     => scalar(server->keyword_channel->message_log),
            irc_nick => irc_nick,
        }
    );
    server->keyword_channel->clear_unread();
    $res;
}

1;
