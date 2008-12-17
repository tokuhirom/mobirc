package App::Mobirc::Web::C::Ajax;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    render_td('Ajax', 'base');
}

sub dispatch_channel {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    my $res = render_td( 'Ajax', 'channel', $channel );
    $channel->clear_unread();
    return $res;
}

sub post_dispatch_channel {
    my $channel = param('channel');
    my $message = param('msg');

    DEBUG "POST MESSAGE $message";

    server->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain',
        body         => 'ok',
    );
}

sub dispatch_menu {
    render_td( 'Ajax', 'menu' );
}

sub dispatch_keyword {
    my $res = render_td('Ajax', 'keyword');
    server->keyword_channel->clear_unread();
    $res;
}

1;
