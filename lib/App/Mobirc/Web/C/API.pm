package App::Mobirc::Web::C::API;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/encode_json/;

sub dispatch_members {
    my $channel = param('channel') or die;

    my $members = server->get_channel($channel)->members();

    my $body = encode_json $members;

    Plack::Response->new(
        200,
        ['Content-Type' => 'application/json;charset=utf-8'],
        $body,
    );
}
*post_dispatch_members = *dispatch_members;

1;
