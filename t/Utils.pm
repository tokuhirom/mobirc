package t::Utils;
use strict;
use warnings;
use lib 'extlib';
use HTTP::Engine;
use App::Mobirc::Web::Middleware::MobileAgent;
use HTTP::Request;

sub import {
    my $pkg = caller(0);
    my $class = shift;

    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/test_he test_he_filter/) {
            *{"${pkg}::${meth}"} = *{"${class}::${meth}"};
        }
    }
}

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
