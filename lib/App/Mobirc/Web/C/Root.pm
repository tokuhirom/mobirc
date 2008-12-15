package App::Mobirc::Web::C::Root;
use Mouse;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_index {
    my ($class, $req) = @_;

    render_td(
        $req,
        'Root', 'index' => (
            $req,
        )
    );
}

1;
