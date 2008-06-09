package App::Mobirc::Web::C::Mobile;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use URI::Escape qw(uri_escape_utf8);
use Encode;
use Encode::JP::Mobile;

sub dispatch_index {
    my ($class, $c) = @_;

    return render_td(
        $c,
        'mobile/top' => {
            exists_recent_entries => scalar( grep { $_->unread_lines } server->channels ),
            mobile_agent       => $c->req->mobile_agent,
            keyword_recent_num => server->keyword_channel->unread_lines(),
            channels           => scalar( server->channels_sorted ),
        }
    );
}

# recent messages on every channel
sub dispatch_recent {
    my ($class, $c) = @_;

    my @unread_channels =
      grep { $_->unread_lines }
      context->channels;

    my $out = render_td(
        $c,
        'mobile/recent' => {
            channel       => $unread_channels[0],
            has_next_page => (scalar(@unread_channels) >= 2 ? 1 : 0),
            irc_nick      => irc_nick,
            mobile_agent  => $c->req->mobile_agent,
        },
    );

    # reset counter.
    if (my $channel = $unread_channels[0]) {
        $channel->clear_unread;
    }

    return $out;
}

    # SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
    # because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
sub dispatch_clear_all_unread {
    my ($class, $c) = @_;

    for my $channel (server->channels) {
        $channel->clear_unread;
    }

    $c->res->redirect('/mobile/');
}

# topic on every channel
sub dispatch_topics {
    my ($class, $c) = @_;

    render_td(
        $c => (
            'mobile/topics' => {
                mobile_agent => $c->req->mobile_agent,
                channels     => scalar( server->channels ),
            }
        )
    );
}

sub dispatch_keyword {
    my ($class, $c, ) = @_;

    my $channel = server->keyword_channel;

    render_td(
        $c,
        'mobile/keyword' => {
            mobile_agent => $c->req->mobile_agent,
            rows         => (
                  $c->req->params->{recent_mode}
                ? scalar($channel->recent_log)
                : scalar($channel->message_log)
            ),
            irc_nick => irc_nick,
        },
    );

    $channel->clear_unread;
}

sub dispatch_channel {
    my ($class, $c, $args, ) = @_;

    my $channel_name = $c->req->params->{channel};
    DEBUG "show channel page: $channel_name";

    my $channel = context->get_channel($channel_name);

    render_td(
        $c,
        'mobile/channel' => {
            mobile_agent        => $c->req->mobile_agent,
            channel             => $channel,
            recent_mode         => $c->req->params->{recent_mode} || undef,
            message             => $c->req->params->{'msg'} || '',
            channel_page_option => context->run_hook('channel_page_option', $channel, $c) || [],
            irc_nick            => irc_nick,
        }
    );

    $channel->clear_unread;
}

sub post_dispatch_channel {
    my ( $class, $c, $args) = @_;

    my $channel = $c->req->params->{channel};

    my $message = $c->req->params->{'msg'};

    DEBUG "POST MESSAGE $message";

    context->get_channel($channel)->post_command($message);

    $c->res->redirect( $c->req->uri->path . "?channel=" . uri_escape_utf8($channel));
}

1;
