package App::Mobirc::Web::Middleware::Encoding;
use Moose;
use Data::Visitor::Encode;

sub wrap {
    my ($class, $next) = @_;

    sub {
        my $req = shift;

        my $encoding = $req->mobile_agent->encoding;
        for my $method (qw/params query_params body_params/) {
            $req->$method( Data::Visitor::Encode->decode($encoding, $req->$method) );
        }

        $next->($req);
    };
}

1;
