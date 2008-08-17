package App::Mobirc::Web::C::Root;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_index {
    my ($class, $req) = @_;

    render_td(
        $req,
        'root/index' => (
            mobile_agent => $req->mobile_agent,
        )
    );
}

1;
