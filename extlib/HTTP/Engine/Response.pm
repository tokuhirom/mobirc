package HTTP::Engine::Response;
use Any::Moose;

use HTTP::Status ();
use HTTP::Headers::Fast;
use HTTP::Engine::Types::Core qw( Header );

# Mouse, Moose role merging is borked with attributes
#with qw(HTTP::Engine::Response);

sub BUILD {
    my ( $self, $param ) = @_;

    for my $field (qw(content_type)) {
        if ( my $val = $param->{$field} ) {
            $self->$field($val);
        }
    }
}

has body => (
    is      => 'rw',
    isa     => 'Any',
    default => '',
);
sub content { shift->body(@_) } # alias

has cookies => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has protocol => (
    is      => 'rw',
#    isa     => 'Str',
);

has status => (
    is      => 'rw',
    isa     => 'Int',
    default => 200,
);

sub code { shift->status(@_) }

has headers => (
    is      => 'rw',
    isa     => Header,
    coerce  => 1,
    default => sub { HTTP::Headers::Fast->new },
    handles => [ qw(content_encoding content_length content_type header) ],
);

sub is_info     { HTTP::Status::is_info     (shift->status) }
sub is_success  { HTTP::Status::is_success  (shift->status) }
sub is_redirect { HTTP::Status::is_redirect (shift->status) }
sub is_error    { HTTP::Status::is_error    (shift->status) }

*output = \&body;

sub set_http_response {
    my ($self, $res) = @_;
    $self->status( $res->code );
    $self->headers( $res->headers->clone );
    $self->body( $res->content );
    $self;
}

sub as_http_response {
    my $self = shift;

    require HTTP::Response;
    HTTP::Response->new(
        $self->status,
        '',
        $self->headers->clone,
        $self->body, # FIXME slurp file handles
    );
}

no Any::Moose;
__PACKAGE__->meta->make_immutable(inline_destructor => 1);
1;
__END__

=for stopwords URL

=head1 NAME

HTTP::Engine::Response - HTTP response object

=head1 SYNOPSIS

    sub handle_request {
        my $req = shift;
        my $res = HTTP::Engine::Response->new;
        $res->body('foo');
        return $res;
    }

=head1 ATTRIBUTES

=over 4

=item body

Sets or returns the output (text or binary data). If you are returning a large body,
you might want to use a L<IO::FileHandle> type of object (Something that implements the read method
in the same fashion), or a filehandle GLOB. HTTP::Engine will write it piece by piece into the response.

=item cookies


Returns a reference to a hash containing cookies to be set. The keys of the
hash are the cookies' names, and their corresponding values are hash
references used to construct a L<CGI::Cookie> object.

        $res->cookies->{foo} = { value => '123' };

The keys of the hash reference on the right correspond to the L<CGI::Cookie>
parameters of the same name, except they are used without a leading dash.
Possible parameters are:

=item status

Sets or returns the HTTP status.

    $res->status(404);

=item headers

Returns an L<HTTP::Headers> object, which can be used to set headers.

    $res->headers->header( 'X-HTTP-Engine' => $HTTP::Engine::VERSION );

=item set_http_response

set a L<HTTP::Response> into $self.

=back

=head1 AUTHORS

Kazuhiro Osawa and HTTP::Engine Authors.

=head1 THANKS TO

L<Catalyst::Response>

=head1 SEE ALSO

L<HTTP::Engine> L<HTTP::Response>, L<Catalyst::Response>

