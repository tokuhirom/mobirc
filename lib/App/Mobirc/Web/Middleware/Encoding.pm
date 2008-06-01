package App::Mobirc::Web::Middleware::Encoding;
use Moose;
use Data::Visitor::Encode;

my $dve = Data::Visitor::Encode->new;

sub wrap {
    my ($next, $c) = @_;

    my $encoding = $c->req->mobile_agent->encoding;
    for my $method (qw/params query_params body_params/) {
        $c->req->$method( $dve->decode($encoding, $c->req->$method) );
    }

    $next->($c);
}

1;
