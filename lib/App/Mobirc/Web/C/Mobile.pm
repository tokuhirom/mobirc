package App::Mobirc::Web::C::Mobile;
use strict;
use warnings;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);
use URI::Escape qw/uri_escape/;

sub dispatch_index {
    render();
}

# recent messages on every channel
sub dispatch_recent {
    my @target_channels;
    my $log_counter   = 0;
    my $has_next_page = 0;

    for my $channel (global_context->unread_channels) {
        push @target_channels, $channel;
        $log_counter += $channel->recent_log_count;

        if ($log_counter >= config->{global}->{recent_log_per_page}) {
            $has_next_page = 1;
            last;
        }
    }

    my $res = render(
        \@target_channels,
        $has_next_page,
    );

    # reset counter.
    for my $channel (@target_channels) {
        $channel->clear_unread;
    }

    return $res;
}

sub dispatch_clear_all_unread {
    for my $channel (global_context->unread_channels) {
        $channel->clear_unread;
    }

    redirect('/mobile/');
}

# topic on every channel
sub dispatch_topics {
    render();
}

sub dispatch_keyword {
    my $channel = global_context->keyword_channel;

    my $res = render(
            param('recent_mode')
        ? scalar($channel->recent_log)
        : scalar($channel->message_log)
    );

    $channel->clear_unread;

    return $res;
}

sub decode_urlsafe_encoded {
    my $name = shift;
    decode_utf8 urlsafe_b64decode(param($name));
}

sub dispatch_channel {
    my $channel_name = decode_urlsafe_encoded('channel');
    DEBUG "show channel page: $channel_name";

    my $server_id = param('server');
    my $server = global_context->get_server($server_id) or die "Unknown server: $server_id";
    my $channel = $server->get_channel($channel_name);

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

    # t=time() is hack for fucking au phone.
    # au phone doesn't clear the body of <input /> when redirect to same url
    redirect(req->uri->path . "?channel=" . $channel->name_urlsafe_encoded . '&t=' . time() . '&server=' . uri_escape($channel->server->id));
}

sub dispatch_members {
    my $channel_name = decode_urlsafe_encoded('channel') || die;

    my @members = server->get_channel($channel_name)->members;
    render( $channel_name, \@members );
}

1;
