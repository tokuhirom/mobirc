package App::Mobirc::Web::C::Ajax;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_base {
    render();
}

sub dispatch_log {
    my $channel_name = param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    my $res = render( $channel );
    $channel->clear_unread();
    return $res;
}

1;
