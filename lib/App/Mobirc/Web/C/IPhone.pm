package App::Mobirc::Web::C::IPhone;
use strict;
use warnings;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;

sub dispatch_base {
    render();
}

sub dispatch_channel {
    my $channel_name = param('channel');

    my $channel = server->get_channel($channel_name);
    my $meth = param('recent') ? 'recent_log' : 'message_log';
    my $body = encode_json(
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

    Plack::Response->new(
        200,
        ['Content-Type' => 'text/json;charset=utf-8', 'Content-Length' => length($body)],    # FIXME invalid
        $body,
    );
}

sub post_dispatch_channel {
    my $channel = param('channel');
    my $message = param('msg');

    server->get_channel($channel)->post_command($message);

    Plack::Response->new(
        200,
        ['Content-Type' => 'text/plain'],
        'ok',
    );
}

sub dispatch_menu {
    render();
}

sub dispatch_keyword {
    my $res = render();
    server->keyword_channel->clear_unread();
    return $res;
}

1;
