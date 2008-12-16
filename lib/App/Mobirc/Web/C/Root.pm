package App::Mobirc::Web::C::Root;
use App::Mobirc::Web::C;

sub dispatch_index {
    my ($class, $req) = @_;

    render_td( 'Root', 'index' );
}

1;
