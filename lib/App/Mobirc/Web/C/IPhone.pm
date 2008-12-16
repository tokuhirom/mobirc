package App::Mobirc::Web::C::IPhone;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;

sub dispatch_base {
    my ($class, $req) = @_;

    render_td(
        'iphone/base' => (
            user_agent => $req->user_agent,
            docroot    => (App::Mobirc->context->{config}->{httpd}->{root} || '/'),
        )
    );
}

sub dispatch_channel {
    my ($class, $req,) = @_;
    my $channel_name = param('channel');

    my $channel = server->get_channel($channel_name);
    my $body;
    if (@{$channel->message_log}) {
        my $meth = param('recent') ? 'recent_log' : 'message_log';
        $body = encode_json(
            {
                messages => [
                    map {
                        render_irc_message( $_ )
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
    my $channel = param('channel');
    my $message = param('msg');

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
        'iphone/menu' => (
            server             => server,
            keyword_recent_num => server->keyword_channel->unread_lines,
        )
    );
}

sub dispatch_keyword {
    my ($class, $req ) = @_;

    my $res = render_td(
        'iphone/keyword' => {
            logs     => scalar(server->keyword_channel->message_log),
        }
    );
    server->keyword_channel->clear_unread();
    return $res;
}

1;
