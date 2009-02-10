package HTTP::Engine::Middleware::Encode;
use HTTP::Engine::Middleware;
use Data::Visitor::Encode;

before_handle {
    my ( $c, $self, $req ) = @_;

    if (( $req->headers->header('Content-Type') || '' ) =~ /charset=(.+);?$/ )
    {

        # decode parameters
        my $encoding = $1;
        for my $method (qw/params query_params body_params/) {
            $req->$method(
                Data::Visitor::Encode->decode( $encoding, $req->$method ) );
        }
    }
    $req;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::Encode - documentation is TODO

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(qw/ HTTP::Engine::Middleware::Encode /);
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 SEE ALSO

L<Data::Visitor::Encode>

=cut
