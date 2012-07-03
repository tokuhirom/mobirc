package App::Mobirc::Web::C::API;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;

sub _render_json {
    my $stuff = shift;

    my $body = encode_json $stuff;
    Plack::Response->new(
        200,
        ['Content-Type' => 'application/json;charset=utf-8', 'Content-Length' => length($body)],
        $body,
    );
}

sub dispatch_members {
    my $channel = param('channel') or die;

    my $members = server->get_channel($channel)->members();

    return _render_json($members);
}
*post_dispatch_members = *dispatch_members;

sub dispatch_keyword {
    my $chan = server->keyword_channel;
    my @log = map {
        +{
            who     => $_->who,
            time    => $_->time,
            body    => $_->body,
            channel => { name => $_->channel->name }
          }
    } $chan->recent_log();
    $chan->clear_unread();
    return _render_json(\@log);
}
*post_dispatch_keyword = *dispatch_keyword;

sub post_dispatch_send_msg {
    my $channel = param('channel') || die "missing channel";
    my $message = param('msg');

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    Plack::Response->new(
        200,
        ['Content-Type' => 'text/plain'],
        'ok',
    );
}

sub dispatch_channels {
    my $channels = [
        map {
            +{
                mtime        => $_->mtime,
                unread_lines => $_->unread_lines,
                name         => $_->name,
                fullname     => $_->fullname,
                server       => $_->server->id,
            }
        } global_context->channels()
    ];

    return _render_json($channels);
}


sub dispatch_channel_log {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    my $res = [map { $_->as_hashref } $channel->message_log];
    $channel->clear_unread();
    return _render_json($res);
}

sub dispatch_clear_all_unread {
    for my $channel (global_context->channels) {
        $channel->clear_unread;
    }

    return _render_json([]);
}

sub dispatch_channel_topic {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    return _render_json({topic => $channel->topic});
}

1;
