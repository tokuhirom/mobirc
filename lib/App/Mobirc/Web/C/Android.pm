package App::Mobirc::Web::C::Android;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);
use JSON qw/encode_json/;

sub dispatch_index {
    my $res = render();
    $res->header('Cache-Control' => 'no-cache, no-store, must-revalidate');
    $res->header('Pragma' => 'no-cache');
    $res;
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

    redirect(req->uri->path . "?channel=" . $channel->name_urlsafe_encoded);
}

# recent messages on every channel
sub dispatch_recent {
    my @target_channels;
    my $log_counter   = 0;
    my $has_next_page = 0;

    for my $channel (server->unread_channels) {
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
    for my $channel (server->channels) {
        $channel->clear_unread;
    }

    redirect('/android/');
}

# topic on every channel
sub dispatch_topics {
    render();
}

sub dispatch_keyword {
    my $channel = server->keyword_channel;

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

sub dispatch_channels {
    my $body = encode_json [
        map {
            +{
                unread       => $_->unread_lines,
                name         => $_->name,
                encoded_name => $_->name_urlsafe_encoded,
            }
        }
        server->channels
    ];

    Plack::Response->new(
        200,
        ['Content-Type' => 'application/json'],
        $body,
    );
}

1;
__END__



