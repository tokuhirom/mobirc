package App::Mobirc::Web::C::IPhone2;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use URI::Escape qw/uri_unescape/;
use JSON qw/encode_json/;

sub decode_url_encoded {
    my $name = shift;
    decode_utf8 uri_unescape(param($name));
}

sub dispatch_base {
    render();
}

sub dispatch_channel {
    my $channel_name = decode_url_encoded('channel');
    DEBUG "show channel page: $channel_name";

    my $channel = server->get_channel($channel_name);

    my $res = render(
        $channel,
        context->run_hook('channel_page_option', $channel) || [],
    );

    $channel->clear_unread;

    return $res;
}

sub post_dispatch_channel {
    my $channel = param('channel');
    my $message = param('msg');
    DEBUG "post '$channel' '$message'";

    server->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain',
        body         => 'ok',
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

sub dispatch_clear_all_unread {
    for my $channel (server->channels) {
        $channel->clear_unread;
    }

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain',
        body         => 'ok',
    );
}

1;
