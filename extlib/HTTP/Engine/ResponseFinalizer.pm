package HTTP::Engine::ResponseFinalizer;
use strict;
use warnings;
use Scalar::Util        ();
use Carp                ();
use CGI::Simple::Cookie;

sub finalize {
    my ($class, $req, $res) = @_;
    Carp::confess 'argument missing: $res' unless $res;

    # protocol
    $res->protocol( $req->protocol ) unless $res->protocol;

    # Content-Length
    if ($res->body) {
        # get the length from a filehandle
        if ((Scalar::Util::blessed($res->body) && $res->body->can('read')) || (ref($res->body) eq 'GLOB')) {
            my $st_size = 7; # see perldoc -f stat
            if (my $size = eval { (stat($res->body))[$st_size] }) {
                $res->content_length($size);
            } else {
                die "Serving filehandle without a content-length($@)";
            }
        } else {
            use bytes;
            $res->content_length(bytes::length($res->body));
        }
    } else {
        $res->content_length(0);
    }

    # Errors
    if ($res->status =~ /^(1\d\d|[23]04)$/) {
        $res->headers->remove_header("Content-Length");
        $res->body('');
    }

    $res->content_type('text/html') unless $res->content_type;
    $res->header(Status => $res->status);

    $class->_finalize_cookies($res);

    # HTTP/1.1's default Connection: close
    if ($res->protocol && $res->protocol =~ m!1\.1! && !!!$res->header('Connection')) {
        $res->header( Connection => 'close' );
    }

    $res->body('') if ((defined $req->method) and ($req->method eq 'HEAD'));
}

sub _finalize_cookies  {
    my ($class, $res) = @_;

    my $cookies = $res->cookies;
    my @keys = keys %$cookies;
    if (@keys) {
        for my $name (@keys) {
            my $val = $cookies->{$name};
            my $cookie = (
                Scalar::Util::blessed($val)
                ? $val
                : CGI::Simple::Cookie->new(
                    -name    => $name,
                    -value   => $val->{value},
                    -expires => $val->{expires},
                    -domain  => $val->{domain},
                    -path    => $val->{path},
                    -secure  => ($val->{secure} || 0)
                )
            );

            $res->headers->push_header('Set-Cookie' => $cookie->as_string);
        }
    }
}

1;
