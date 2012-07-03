package App::Mobirc::Web::C::IPhone2;
use strict;
use warnings;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use URI::Escape qw/uri_unescape uri_escape/;
use JSON qw/encode_json/;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);

sub decode_urlsafe_encoded {
    my $name = shift;
    decode_utf8 urlsafe_b64decode(param($name));
}

sub dispatch_base {
    render();
}

sub dispatch_channel {
    my $channel_name = decode_urlsafe_encoded('channel');
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
    my $channel_name = decode_urlsafe_encoded('channel');
    my $message = param('msg');

    DEBUG "POST MESSAGE $message";

    my $channel = server->get_channel($channel_name);
    $channel->post_command($message);

    redirect(req->uri->path . "?channel=" . $channel->name_urlsafe_encoded . '&t=' . time() . '&server=' . uri_escape($channel->server->id));
}

sub dispatch_menu {
    render();
}

1;
