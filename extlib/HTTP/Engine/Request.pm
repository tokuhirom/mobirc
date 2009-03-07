package HTTP::Engine::Request;
use Any::Moose;
use HTTP::Headers::Fast;
use HTTP::Engine::Types::Core qw( Uri Header );
use URI::QueryParam;
require Carp; # Carp->import is too heavy =(

# Mouse, Moose role merging is borked with attributes
#with qw(HTTP::Engine::Request);

# this object constructs all our lazy fields for us
has request_builder => (
    does     => "HTTP::Engine::Role::RequestBuilder",
    is       => "rw",
    required => 1,
);

sub BUILD {
    my ( $self, $param ) = @_;

    foreach my $field qw(base path) {
        if ( my $val = $param->{$field} ) {
            $self->$field($val);
        }
    }
}

has _connection => (
    is => "ro",
    isa => 'HashRef',
    required => 1,
);

has "_read_state" => (
    is => "rw",
    lazy_build => 1,
);

sub _build__read_state {
    my $self = shift;
    $self->request_builder->_build_read_state($self);
}

has connection_info => (
    is => "rw",
    isa => "HashRef",
    lazy_build => 1,
);

sub _build_connection_info {
    my $self = shift;
    $self->request_builder->_build_connection_info($self);
}

has cookies => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy_build => 1,
);

sub _build_cookies {
    my $self = shift;
    $self->request_builder->_build_cookies($self);
}

foreach my $attr qw(address method protocol user port _https_info request_uri) {
    has $attr => (
        is => 'rw',
        # isa => "Str",
        lazy => 1,
        default => sub { shift->connection_info->{$attr} },
    );
}
has query_parameters => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy_build => 1,
);

sub _build_query_parameters {
    my $self = shift;
    $self->uri->query_form_hash;
}

# https or not?
has secure => (
    is      => 'rw',
    isa     => 'Bool',
    lazy_build => 1,
);

sub _build_secure {
    my $self = shift;

    if ( my $https = $self->_https_info ) {
        return 1 if uc($https) eq 'ON';
    }

    if ( my $port = $self->port ) {
        return 1 if $port == 443;
    }

    return 0;
}

# proxy request?
has proxy_request => (
    is         => 'rw',
    isa        => 'Str', # TODO: union(Uri, Undef) type
#    coerce     => 1,
    lazy_build => 1,
);

sub _build_proxy_request {
    my $self = shift;
    return '' unless $self->request_uri;                   # TODO: return undef
    return '' unless $self->request_uri =~ m!^https?://!i; # TODO: return undef
    return $self->request_uri;                             # TODO: return URI->new($self->request_uri);
}

has uri => (
    is     => 'rw',
    isa => Uri,
    coerce => 1,
    lazy_build => 1,
    handles => [qw(base path)],
);

sub _build_uri {
    my $self = shift;
    $self->request_builder->_build_uri($self);
}

has raw_body => (
    is      => 'rw',
    isa     => 'Str',
    lazy_build => 1,
);

sub _build_raw_body {
    my $self = shift;
    $self->request_builder->_build_raw_body($self);
}

has headers => (
    is      => 'rw',
    isa => Header,
    coerce  => 1,
    lazy_build => 1,
    handles => [ qw(content_encoding content_length content_type header referer user_agent) ],
);

sub _build_headers {
    my $self = shift;
    $self->request_builder->_build_headers($self);
}

# Contains the URI base. This will always have a trailing slash.
# If your application was queried with the URI C<http://localhost:3000/some/path> then C<base> is C<http://localhost:3000/>.

has hostname => (
    is      => 'rw',
    isa     => 'Str',
    lazy_build => 1,
);

sub _build_hostname {
    my $self = shift;
    $self->request_builder->_build_hostname($self);
}

has http_body => (
    is         => 'rw',
    isa        => 'HTTP::Body',
    lazy_build => 1,
    handles => {
        body_parameters => 'param',
        body            => 'body',
    },
);

sub _build_http_body {
    my $self = shift;
    $self->request_builder->_build_http_body($self);
}

# contains body_params and query_params
has parameters => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy_build => 1,
);

sub _build_parameters {
    my $self = shift;

    my $query = $self->query_parameters;
    my $body = $self->body_parameters;

    my %merged;

    foreach my $hash ( $query, $body ) {
        foreach my $name ( keys %$hash ) {
            my $param = $hash->{$name};
            push( @{ $merged{$name} ||= [] }, ( ref $param ? @$param : $param ) );
        }
    }

    foreach my $param ( values %merged ) {
        $param = $param->[0] if @$param == 1;
    }

    return \%merged;
}

has uploads => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy_build => 1,
);

sub _build_uploads {
    my $self = shift;
    $self->request_builder->_prepare_uploads($self);
}

# aliases
*body_params  = \&body_parameters;
*input        = \&body;
*params       = \&parameters;
*query_params = \&query_parameters;
*path_info    = \&path;

sub cookie {
    my $self = shift;

    return keys %{ $self->cookies } if @_ == 0;

    if (@_ == 1) {
        my $name = shift;
        return undef unless exists $self->cookies->{$name}; ## no critic.
        return $self->cookies->{$name};
    }
    return;
}

sub param {
    my $self = shift;

    return keys %{ $self->parameters } if @_ == 0;

    if (@_ == 1) {
        my $param = shift;
        return wantarray ? () : undef unless exists $self->parameters->{$param};

        if ( ref $self->parameters->{$param} eq 'ARRAY' ) {
            return (wantarray)
              ? @{ $self->parameters->{$param} }
                  : $self->parameters->{$param}->[0];
        } else {
            return (wantarray)
              ? ( $self->parameters->{$param} )
                  : $self->parameters->{$param};
        }
    } else {
        my $field = shift;
        $self->parameters->{$field} = [@_];
    }
}

sub upload {
    my $self = shift;

    return keys %{ $self->uploads } if @_ == 0;

    if (@_ == 1) {
        my $upload = shift;
        return wantarray ? () : undef unless exists $self->uploads->{$upload};

        if (ref $self->uploads->{$upload} eq 'ARRAY') {
            return (wantarray)
              ? @{ $self->uploads->{$upload} }
          : $self->uploads->{$upload}->[0];
        } else {
            return (wantarray)
              ? ( $self->uploads->{$upload} )
          : $self->uploads->{$upload};
        }
    } else {
        while ( my($field, $upload) = splice(@_, 0, 2) ) {
            if ( exists $self->uploads->{$field} ) {
                for ( $self->uploads->{$field} ) {
                    $_ = [$_] unless ref($_) eq "ARRAY";
                    push(@{ $_ }, $upload);
                }
            } else {
                $self->uploads->{$field} = $upload;
            }
        }
    }
}

sub uri_with {
    my($self, $args) = @_;
    
    Carp::carp( 'No arguments passed to uri_with()' ) unless $args;

    for my $value (values %{ $args }) {
        next unless defined $value;
        for ( ref $value eq 'ARRAY' ? @{ $value } : $value ) {
            $_ = "$_";
            utf8::encode( $_ );
        }
    };
    
    my $uri = $self->uri->clone;
    
    $uri->query_form( {
        %{ $uri->query_form_hash },
        %{ $args },
    } );
    return $uri;
}

sub as_http_request {
    my $self = shift;
    require 'HTTP/Request.pm'; ## no critic
    HTTP::Request->new( $self->method, $self->uri, $self->headers, $self->raw_body );
}

sub absolute_url {
    my ($self, $location) = @_;

    unless ($location =~ m!^https?://!) {
        return URI->new( $location )->abs( $self->base );
    } else {
        return $location;
    }
}

sub content {
    my ( $self, @args ) = @_;

    if ( @args ) {
        Carp::croak "The HTTP::Request method 'content' is unsupported when used as a writer, use HTTP::Engine::RequestBuilder";
    } else {
        return $self->raw_body;
    }
}

sub as_string {
    my $self = shift;
    $self->as_http_request->as_string; # FIXME not efficient
}

sub parse {
    Carp::croak "The HTTP::Request method 'parse' is unsupported, use HTTP::Engine::RequestBuilder";
}

no Any::Moose;
1;
__END__

=for stopwords Stringifies URI http https param CGI.pm-compatible referer uri IP hostname API enviroments

=head1 NAME

HTTP::Engine::Request - Portable HTTP request object

=head1 SYNOPSIS

    # normally a request object is passed into your handler
    sub handle_request {
        my $req = shift;

   };

=head1 DESCRIPTION

L<HTTP::Engine::Request> provides a consistent API for request objects across web
server enviroments. 

=head1 METHODS

=head2 new

    HTTP::Engine::Request->new(
        request_builder => $BUILDER,
        _connection => {
            env           => \%ENV,
            input_handle  => \*STDIN,
            output_handle => \*STDOUT,
        },
        %args
    );

Normally, new() is not called directly, but a pre-built HTTP::Engine::Request
object is passed for you into your request handler. You may build your own,
following the example above. The C<$BUILDER> may be one of
L<HTTP::Engine::RequestBuilder::CGI> or L<HTTP::Engine::RequestBuilder::NoEnv>.

=head1 ATTRIBUTES

=over 4

=item address

Returns the IP address of the client.

=item cookies

Returns a reference to a hash containing the cookies

=item method

Contains the request method (C<GET>, C<POST>, C<HEAD>, etc).

=item protocol

Returns the protocol (HTTP/1.0 or HTTP/1.1) used for the current request.

=item request_uri

Returns the request uri (like $ENV{REQUEST_URI})

=item query_parameters

Returns a reference to a hash containing query string (GET) parameters. Values can                                                    
be either a scalar or an arrayref containing scalars.

=item secure

Returns true or false, indicating whether the connection is secure (https).

=item proxy_request

Returns undef or uri, if it is proxy request, uri of a connection place is returned.

=item uri

Returns a URI object for the current request. Stringifies to the URI text.

=item user

Returns REMOTE_USER.

=item raw_body

Returns string containing body(POST).

=item headers

Returns an L<HTTP::Headers> object containing the headers for the current request.

=item base

Contains the URI base. This will always have a trailing slash.

=item hostname

Returns the hostname of the client.

=item http_body

Returns an L<HTTP::Body> object.

=item parameters

Returns a reference to a hash containing GET and POST parameters. Values can
be either a scalar or an arrayref containing scalars.

=item uploads

Returns a reference to a hash containing uploads. Values can be either a
L<HTTP::Engine::Request::Upload> object, or an arrayref of
L<HTTP::Engine::Request::Upload> objects.

=item content_encoding

Shortcut to $req->headers->content_encoding.

=item content_length

Shortcut to $req->headers->content_length.

=item content_type

Shortcut to $req->headers->content_type.

=item header

Shortcut to $req->headers->header.

=item referer

Shortcut to $req->headers->referer.

=item user_agent

Shortcut to $req->headers->user_agent.

=item cookie

A convenient method to access $req->cookies.

    $cookie  = $req->cookie('name');
    @cookies = $req->cookie;

=item param

Returns GET and POST parameters with a CGI.pm-compatible param method. This 
is an alternative method for accessing parameters in $req->parameters.

    $value  = $req->param( 'foo' );
    @values = $req->param( 'foo' );
    @params = $req->param;

Like L<CGI>, and B<unlike> earlier versions of Catalyst, passing multiple
arguments to this method, like this:

    $req->param( 'foo', 'bar', 'gorch', 'quxx' );

will set the parameter C<foo> to the multiple values C<bar>, C<gorch> and
C<quxx>. Previously this would have added C<bar> as another value to C<foo>
(creating it if it didn't exist before), and C<quxx> as another value for
C<gorch>.

=item path

Returns the path, i.e. the part of the URI after $req->base, for the current request.

=item upload

A convenient method to access $req->uploads.

    $upload  = $req->upload('field');
    @uploads = $req->upload('field');
    @fields  = $req->upload;

    for my $upload ( $req->upload('field') ) {
        print $upload->filename;
    }


=item uri_with

Returns a rewritten URI object for the current request. Key/value pairs
passed in will override existing parameters. Unmodified pairs will be
preserved.

=item as_http_request

convert HTTP::Engine::Request to HTTP::Request.

=item $req->absolute_url($location)

convert $location to absolute uri.

=back

=head1 AUTHORS

Kazuhiro Osawa and HTTP::Engine Authors.

=head1 THANKS TO

L<Catalyst::Request>

=head1 SEE ALSO

L<HTTP::Request>, L<Catalyst::Request>

