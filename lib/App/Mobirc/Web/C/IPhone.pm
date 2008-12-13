package App::Mobirc::Web::C::IPhone;
use Mouse;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;

sub dispatch_base {
    my ($class, $req) = @_;

    render_td(
        $req,
        'iphone/base' => (
            user_agent => $req->user_agent,
            docroot    => (App::Mobirc->context->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_channel {
    my ($class, $req,) = @_;
    my $channel_name = $req->params->{channel};

    my $channel = server->get_channel($channel_name);
    my $body;
    if (@{$channel->message_log}) {
        my $meth = $req->query_params->{recent} ? 'recent_log' : 'message_log';
        $body = encode_json(
            {
                messages => [
                    map {
                        App::Mobirc::Web::View->show( 'irc_message', $_, irc_nick )
                    } reverse $channel->$meth
                ],
                channel_name => $channel->name,
            }
        );

        $channel->clear_unread();
    } else {
        $body = '';
    }
    $channel->clear_unread();

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/json',    # FIXME invalid
        body         => $body,
    );
}

sub post_dispatch_channel {
    my ( $class, $req, ) = @_;
    my $channel = $req->params->{'channel'};
    my $message = $req->params->{'msg'};

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain',
        body         => 'ok',
    );
}

sub dispatch_menu {
    my ($class, $req ) = @_;

    render_td(
        $req,
        'iphone/menu' => (
            server             => server,
            keyword_recent_num => server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_keyword {
    my ($class, $req ) = @_;

    my $res = render_td(
        $req,
        'iphone/keyword' => {
            logs     => scalar(server->keyword_channel->message_log),
            irc_nick => irc_nick,
        }
    );
    server->keyword_channel->clear_unread();
    return $res;
}

1;
