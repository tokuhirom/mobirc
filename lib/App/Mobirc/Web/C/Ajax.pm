package App::Mobirc::Web::C::Ajax;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    render();
}

sub dispatch_channel {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    my $res = render( $channel );
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
    render();
}

sub dispatch_keyword {
    my $res = render();
    server->keyword_channel->clear_unread();
    $res;
}

1;
