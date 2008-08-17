package App::Mobirc::Web::C::Mobile;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use URI::Escape qw(uri_escape_utf8);
use Encode;
use Encode::JP::Mobile;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);

sub dispatch_index {
    my ($class, $req) = @_;

    return render_td(
        $req,
        'mobile/top' => {
            exists_recent_entries => scalar( grep { $_->unread_lines } server->channels ),
            mobile_agent       => $req->mobile_agent,
            keyword_recent_num => server->keyword_channel->unread_lines(),
            channels           => scalar( server->channels_sorted ),
        }
    );
}

# recent messages on every channel
sub dispatch_recent {
    my ($class, $req) = @_;

    my @target_channels;
    my $log_counter   = 0;
    my $has_next_page = 0;
    my @unread_channels =
      grep { $_->unread_lines }
      context->channels;

    for my $channel (@unread_channels) {
        push @target_channels, $channel;
        $log_counter += $channel->recent_log_count;

        if ($log_counter >= App::Mobirc->context->{config}->{httpd}->{recent_log_per_page}) {
            $has_next_page = 1;
            last;
        }
    }

    my $res = render_td(
        $req,
        'mobile/recent' => {
            channels      => \@target_channels,
            has_next_page => $has_next_page,
            irc_nick      => irc_nick,
            mobile_agent  => $req->mobile_agent,
        },
    );

    # reset counter.
    for my $channel (@target_channels) {
        $channel->clear_unread;
    }

    return $res;
}

    # SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
    # because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
sub dispatch_clear_all_unread {
    my ($class, $req) = @_;

    for my $channel (server->channels) {
        $channel->clear_unread;
    }

    HTTP::Engine::Response->new(
        status   => 302,
        headers  => HTTP::Headers->new(
            Location => '/mobile/',
        ),
    );
}

# topic on every channel
sub dispatch_topics {
    my ($class, $req) = @_;

    render_td(
        $req => (
            'mobile/topics' => {
                mobile_agent => $req->mobile_agent,
                channels     => scalar( server->channels ),
            }
        )
    );
}

sub dispatch_keyword {
    my ($class, $req, ) = @_;

    my $channel = server->keyword_channel;

    my $res = render_td(
        $req,
        'mobile/keyword' => {
            mobile_agent => $req->mobile_agent,
            rows         => (
                  $req->params->{recent_mode}
                ? scalar($channel->recent_log)
                : scalar($channel->message_log)
            ),
            irc_nick => irc_nick,
        },
    );

    $channel->clear_unread;

    return $res;
}

sub decode_urlsafe_encoded {
    my $name = shift;
    decode_utf8 urlsafe_b64decode($name);
}

sub dispatch_channel {
    my ($class, $req, $args, ) = @_;

    my $channel_name = decode_urlsafe_encoded $req->params->{channel};
    DEBUG "show channel page: $channel_name";

    my $channel = context->get_channel($channel_name);

    my $res = render_td(
        $req,
        'mobile/channel' => {
            mobile_agent        => $req->mobile_agent,
            channel             => $channel,
            recent_mode         => $req->params->{recent_mode} || undef,
            message             => $req->params->{'msg'} || '',
            channel_page_option => context->run_hook('channel_page_option', $channel) || [],
            irc_nick            => irc_nick,
        }
    );

    $channel->clear_unread;

    return $res;
}

sub post_dispatch_channel {
    my ( $class, $req, $args) = @_;

    my $channel_name = decode_urlsafe_encoded $req->params->{channel};
    my $message = $req->params->{'msg'};

    DEBUG "POST MESSAGE $message";

    my $channel = context->get_channel($channel_name);
    $channel->post_command($message);

    HTTP::Engine::Response->new(
        status  => 302,
        headers => {
            Location => $req->uri->path . "?channel=" . $channel->name_urlsafe_encoded,
        },
    );
}

1;
