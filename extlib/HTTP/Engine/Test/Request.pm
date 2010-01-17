package HTTP::Engine::Test::Request;
use strict;
use warnings;

use IO::Scalar;
use URI;
use URI::WithBase;
use Scalar::Util 'blessed';

use HTTP::Engine::Request;
use HTTP::Engine::RequestBuilder::NoEnv;

sub new {
    my $class = shift;

    if ($_[0] && ref($_[0]) && $_[0]->isa('HTTP::Request')) {
        # create H::E::Req from HTTP::Request
        my $req  = shift;
        my %args = @_;

        return $class->build_request(
            $req->uri,
            $req->content, {
                headers  => $req->headers,
                method   => $req->method,
                protocol => $req->protocol,
                %args,
            }
        );
    } else {
        # create H::E::Req from hash
        my %args = @_;

        my $body   = delete $args{body} || '';
        my $uri    = delete $args{uri}    or Carp::croak('missing uri');
        my $method = delete $args{method} or Carp::croak('missing method');

        return $class->build_request(
            $uri,
            $body, {
                headers  => +{},
                protocol => undef,
                method   => $method,
                %args
            }
        );
    }
}

sub build_request {
    my ($class, $uri, $body, $args) = @_;

    my %req_args = $class->build_request_args(
        $uri,
        $body,
        $args,
    );

    return HTTP::Engine::Request->new(
        request_builder => HTTP::Engine::RequestBuilder::NoEnv->new,
        %req_args,
    );
}

# This method is used by Interface::Test.
sub build_request_args {
    my($class, $uri, $body, $args) = @_;

    unless (blessed($uri) && $uri->isa('URI')) {
        $uri = URI->new( $uri );
    }

    return (
        uri         => URI::WithBase->new( $uri ),
        base        => do {
            my $base = $uri->clone;
            $base->path_query('/');
            $base;
        },
        address     => '127.0.0.1',
        port        => '80',
        user        => undef,
        _https_info => undef,
        _connection => {
            input_handle  => IO::Scalar->new( \( $body ) ),
            env           => ($args->{env} || {}),
        },
        %$args,
    );
}

1;

__END__

=encoding utf8

=head1 NAME

HTTP::Engine::Test::Request - HTTP::Engine request object builder for test

=head1 SYNOPSIS

    use HTTP::Engine::Test::Request;

    # simple query
    my $req = HTTP::Engine::Test::Request->new(
        uri => 'http://example.com/?foo=bar&bar=baz'
    );
    is $req->method, 'GET', 'GET method';
    is $req->address, '127.0.0.1', 'remote address';
    is $req->uri, 'http://example.com/?foo=bar&bar=baz', 'uri';
    is_deeply $req->parameters, { foo => 'bar', bar => 'baz' }, 'query params';

    # use headers
    my $req = HTTP::Engine::Test::Request->new(
        uri     => 'http://example.com/',
        headers => {
            'Content-Type' => 'text/plain',
        },
    );
    is $req->header('content-type'), 'text/plain', 'content-type';

    # by HTTP::Request object
    my $req = HTTP::Engine::Test::Request->new(
        HTTP::Request->new(
            GET => 'http://example.com/?foo=bar&bar=baz',
            HTTP::Headers::Fast->new(
                'Content-Type' => 'text/plain',
            ),
        )
    );

    is $req->method, 'GET', 'GET method';
    is $req->address, '127.0.0.1', 'remote address';
    is $req->uri, 'http://example.com/?foo=bar&bar=baz', 'uri';
    is_deeply $req->parameters, { foo => 'bar', bar => 'baz' }, 'query params';
    is $req->header('content-type'), 'text/plain', 'content-type';


=head1 DESCRIPTION

HTTP::Engine::Test::Request is HTTP::Engine request object builder.

Please use in a your test.

=head1 SEE ALSO

L<HTTP::Engine::Request>

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>
