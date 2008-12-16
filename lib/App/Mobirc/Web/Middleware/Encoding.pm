package App::Mobirc::Web::Middleware::Encoding;
use Mouse;
use Data::Visitor::Encode;

sub wrap {
    my ($class, $next) = @_;

    sub {
        my $req = shift;

        for my $method (qw/params query_params body_params/) {
            $req->$method( Data::Visitor::Encode->decode_utf8($req->$method) );
        }

        $next->($req);
    };
}

1;
