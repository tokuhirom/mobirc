package App::Mobirc::Web::C::API;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;
use List::MoreUtils qw(any);

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

    DEBUG "POST MESSAGE '$message' for '$channel'";

    server->get_channel($channel)->post_command($message);

    Plack::Response->new(
        200,
        ['Content-Type' => 'text/plain'],
        'ok',
    );
}

sub dispatch_channels {
    my $favorites = ' ' . join(' ', split /\s*,\s*/, lc(config->{global}->{favorites} || '')) . ' ';
    my $channels  = [ sort { -($favorites =~ quotemeta(lc $a->name)) <=> -($favorites =~ quotemeta(lc $b->name)) } server->channels_sorted ];

    my $mangled = [
        map {
            +{
                unread_lines => $_->unread_lines,
                name         => $_->name,
            }
        } grep { $_ } @$channels
    ];

    return _render_json($mangled);
}


sub dispatch_channel_log {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    my $res = [map { $_->as_hashref } $channel->message_log];
    for my $row (@$res) {
        if (any { $row->{message} eq $_ } $channel->recent_log) {
            DEBUG "FRESH";
            $row->{is_new} = 1;
        } else {
            $row->{is_new} = 0;
        }
    }
    DEBUG "channel log: @$res";
    $channel->clear_unread();
    return _render_json($res);
}

sub dispatch_clear_all_unread {
    for my $channel (server->channels) {
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
