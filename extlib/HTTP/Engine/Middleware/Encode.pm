package HTTP::Engine::Middleware::Encode;
use HTTP::Engine::Middleware;
use Data::Visitor::Encode;
use Encode ();
use Scalar::Util ();

has 'detected_decode_by_header' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has 'decode' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'utf-8',
);

has 'encode' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'utf-8',
);

has 'content_type_charset' => (
    is      => 'ro',
    isa     => 'Str',
);

before_handle {
    my ( $c, $self, $req ) = @_;

    my $encoding = $self->decode;
    if ($self->detected_decode_by_header) {
        if (( $req->headers->header('content-type') || '' ) =~ /charset\s*=\s*([^\s]+);?$/ ) {
            $encoding = $1;
        }
    }

    # decode parameters
    for my $method (qw/params query_params body_params/) {
        $req->$method( Data::Visitor::Encode->decode( $encoding, $req->$method ) );
    }
    $req;
};

after_handle {
    my ( $c, $self, $req, $res ) = @_;

    my $body = $res->body;
    return $res unless $body;
    if ((Scalar::Util::blessed($body) && $body->can('read')) || (ref($body) eq 'GLOB')) {
        return $res;
    }
    if (Encode::is_utf8( $body )) {
        my $encoding = $self->encode;
        $res->body( Encode::encode( $encoding, $body ) );

        my $content_type = $res->content_type || 'text/html';
        if ($content_type =~ m!^text/!) {
            $encoding = $self->content_type_charset if $self->content_type_charset;
            unless ($content_type =~ s/charset\s*=\s*[^\s]*;?/charset=$encoding/ ) {
                $content_type .= '; ' unless $content_type =~ /;\s*$/;
                $content_type .= "charset=$encoding";
            }
            $res->content_type( $content_type );
        }
    }

    $res;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::Encode - Encoding Filter

=head1 SYNOPSIS

default: in code = utf8, out code = utf8

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(
        'HTTP::Engine::Middleware::Encode',
    );
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

in code = cp932, out code = cp932 (Shift-JIS)

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(
        'HTTP::Engine::Middleware::Encode' => {
            decode => 'cp932',
            decode => 'cp932',
            content_type_charset => 'Shift-JIS',
        },
    );
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();


in code = detect by Content-Type header (default encoding is utf8), out code = utf8

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(
        'HTTP::Engine::Middleware::Encode' => {
            detected_decode_by_header => 1,
            decode => 'utf8',
        },
    );
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 AUTHORS

precuredaisuki

yappo

=head1 SEE ALSO

L<Data::Visitor::Encode>

=cut
