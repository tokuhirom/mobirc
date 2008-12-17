package App::Mobirc::Web::C::Root;
use App::Mobirc::Web::C;

sub dispatch_index {
    render_td( 'Root', 'index' );
}

1;
