package App::Mobirc::Web::C::Root;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_index {
    my ($class, $c) = @_;

    render_td(
        $c,
        'root/index' => (
            mobile_agent => $c->req->mobile_agent,
        )
    );
}

1;
