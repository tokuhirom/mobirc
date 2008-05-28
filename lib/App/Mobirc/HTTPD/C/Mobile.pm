package App::Mobirc::HTTPD::C::Mobile;
use Moose;
use App::Mobirc::HTTPD::C;
use App::Mobirc::Util;
use URI::Escape qw/uri_escape/;
use Encode;

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

    for my $channel (context->channels) {
        $channel->clear_unread;
    }

    my $root = context->config->{httpd}->{root};
    $c->res->redirect($root);
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

sub post_dispatch_show_channel {
    my ( $class, $c, $channel) = @_;

    my $message = decode( $c->req->mobile_agent->encoding, $c->req->params->{'msg'} );

    DEBUG "POST MESSAGE $message";

    context->get_channel($channel)->post_command($message);

    my $root = context->config->{httpd}->{root};
    $root =~ s!/$!!;

    $c->res->redirect( $root . $c->req->uri->path . '?time=' . time );
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

sub dispatch_show_channel {
    my ($class, $c, $channel_name,) = @_;

    DEBUG "show channel page: $channel_name";

    my $channel = context->get_channel($channel_name);

    render_td(
        $c,
        'mobile/channel' => {
            mobile_agent        => $c->req->mobile_agent,
            channel             => $channel,
            recent_mode         => $c->req->params->{recent_mode},
            channel_page_option => [
                map { $_->( $channel, $c ) }
                  @{ context->get_hook_codes('channel_page_option') }
            ],
            irc_nick            => irc_nick,
        }
    );

    $channel->clear_unread;
}

1;
