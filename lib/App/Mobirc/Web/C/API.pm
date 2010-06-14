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

1;
