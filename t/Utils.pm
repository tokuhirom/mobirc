package t::Utils;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw/test_he test_he_filter/;
use HTTP::Engine;
use App::Mobirc::Web::Middleware::MobileAgent;
use HTTP::Request;

sub test_he {
    my ($req, $cb) = @_;

    HTTP::Engine->new(
        interface => {
            module          => 'Test',
            request_handler => $cb,
        }
    )->run( $req );
}

sub test_he_filter(&) {
    my $cb = shift;

    test_he( HTTP::Request->new('GET', '/'), sub {
        my $req = shift;
        $cb->($req);
        return HTTP::Engine::Response->new( status => 200 );
    });
}

1;
