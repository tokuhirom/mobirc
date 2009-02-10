package HTTP::Engine::Middleware::Unicode;
use HTTP::Engine::Middleware;
use Data::Visitor::Encode;
use Encode ();

before_handle {
    my ( $c, $self, $req ) = @_;
    $self->decode_params($req);
    $req;
};

after_handle {
    my ( $c, $self, $req, $res ) = @_;
    $self->encode_body($res);
    $res;
};

sub encode_body {
    my ( $self, $response ) = @_;

    if ( $response->body && Encode::is_utf8( $response->body ) ) {
        $response->body( Encode::encode_utf8( $response->body ) );
    }
}

sub decode_params {
    my ( $self, $request ) = @_;
    for my $method (qw/params query_params body_params/) {
        $request->$method(
            Data::Visitor::Encode->decode( 'utf8', $request->$method ) );
    }
}

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::Unicode - documentation is TODO

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(qw/ HTTP::Engine::Middleware::Unicode /);
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 SEE ALSO

L<Data::Visitor::Encode>

=cut
