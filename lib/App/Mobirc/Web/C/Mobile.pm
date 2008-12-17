package App::Mobirc::Web::C::Mobile;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use URI::Escape qw(uri_escape_utf8);
use Encode;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);

sub dispatch_index {
    render_td( 'Mobile', 'top' );
}

# recent messages on every channel
sub dispatch_recent {
    my @target_channels;
    my $log_counter   = 0;
    my $has_next_page = 0;

    for my $channel (server->unread_channels) {
        push @target_channels, $channel;
        $log_counter += $channel->recent_log_count;

        if ($log_counter >= App::Mobirc->context->{config}->{httpd}->{recent_log_per_page}) {
            $has_next_page = 1;
            last;
        }
    }

    my $res = render_td(
        'Mobile', 'recent' => {
            channels      => \@target_channels,
            has_next_page => $has_next_page,
        },
    );

    # reset counter.
    for my $channel (@target_channels) {
        $channel->clear_unread;
    }

    return $res;
}

sub dispatch_clear_all_unread {
    my ($class, $req) = @_;

    for my $channel (server->channels) {
        $channel->clear_unread;
    }

    redirect('/mobile/');
}

# topic on every channel
sub dispatch_topics {
    my ($class, $req) = @_;

    render_td('Mobile', 'topics');
}

sub dispatch_keyword {
    my ($class, $req, ) = @_;

    my $channel = server->keyword_channel;

    my $res = render_td(
        'Mobile', 'keyword' => {
            rows         => (
                  param('recent_mode')
                ? scalar($channel->recent_log)
                : scalar($channel->message_log)
            ),
        },
    );

    $channel->clear_unread;

    return $res;
}

sub decode_urlsafe_encoded {
    my $name = shift;
    decode_utf8 urlsafe_b64decode(param($name));
}

sub dispatch_channel {
    my ($class, $req, $args, ) = @_;

    my $channel_name = decode_urlsafe_encoded('channel');
    DEBUG "show channel page: $channel_name";

    my $channel = context->get_channel($channel_name);

    my $res = render_td(
        'Mobile', 'channel' => {
            channel             => $channel,
            channel_page_option => context->run_hook('channel_page_option', $channel) || [],
        }
    );

    $channel->clear_unread;

    return $res;
}

sub post_dispatch_channel {
    my ( $class, $req, $args) = @_;

    my $channel_name = decode_urlsafe_encoded('channel');
    my $message = param('msg');

    DEBUG "POST MESSAGE $message";

    my $channel = context->get_channel($channel_name);
    $channel->post_command($message);

    redirect($req->uri->path . "?channel=" . $channel->name_urlsafe_encoded);
}

1;
