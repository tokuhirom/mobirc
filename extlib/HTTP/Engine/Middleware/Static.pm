package HTTP::Engine::Middleware::Static;
use HTTP::Engine::Middleware;
use HTTP::Engine::Response;

use MIME::Types;
use Path::Class;
use Cwd;
use Any::Moose 'X::Types::Path::Class';
use Any::Moose '::Util::TypeConstraints';
use File::Spec::Unix;

# corece of Regexp
subtype 'HTTP::Engine::Middleware::Static::Regexp'
    => as 'RegexpRef';
coerce 'HTTP::Engine::Middleware::Static::Regexp'
    => from 'Str' => via { qr/$_/ };

has 'regexp' => (
    is       => 'ro',
    isa      => 'HTTP::Engine::Middleware::Static::Regexp',
    coerce   => 1,
    required => 1,
);

has 'docroot' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
);

has directory_index => (
    is  => 'ro',
    isa => 'Str|Undef',
);

has 'mime_types' => (
    is  => 'ro',
    isa => 'MIME::Types',
    lazy => 1,
    default => sub {
        my $mime_types = MIME::Types->new(only_complete => 1);
        $mime_types->create_type_index;
        $mime_types;
    },
);

before_handle {
    my ( $c, $self, $req ) = @_;

    my $re   = $self->regexp;
    my $uri_path = $req->uri->path;
    return $req unless $uri_path && $uri_path =~ /^(?:$re)$/;

    my $docroot = dir($self->docroot)->absolute;
    my $file = do {
        if ($uri_path =~ m{/$} && $self->directory_index) {
            $docroot->file(
                File::Spec::Unix->splitpath($uri_path),
                $self->directory_index
            );
        } else {
            $docroot->file(
                File::Spec::Unix->splitpath($uri_path)
            )
        }
    };

    # check directory traversal
    my $realpath = Cwd::realpath($file->absolute->stringify);
    return HTTP::Engine::Response->new( status => 403, body => 'forbidden') unless $docroot->subsumes($realpath);

    return HTTP::Engine::Response->new( status => '404', body => 'not found' ) unless -e $file;

    my $content_type = 'text/plain';
    if ($file =~ /.*\.(\S{1,})$/xms ) {
        $content_type = $self->mime_types->mimeTypeOf($1);
    }

    my $fh = $file->openr;
    die "Unable to open $file for reading : $!" unless $fh;
    binmode $fh;

    my $res = HTTP::Engine::Response->new( body => $fh, content_type => $content_type );
    my $stat = $file->stat;
    $res->header( 'Content-Length' => $stat->size );
    $res->header( 'Last-Modified'  => $stat->mtime );
    $res;
};


__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::Static - handler for static files

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install( 'HTTP::Engine::Middleware::Static' => {
        regexp  => qr{^/(robots.txt|favicon.ico|(?:css|js|img)/.+)$},
        docroot => '/path/to/htdocs/',
    });
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

    # $ GET http//localhost/css/foo.css
    # to get the /path/to/htdocs/css/foo.css

    # $ GET http//localhost/js/jquery.js
    # to get the /path/to/htdocs/js/jquery.js

    # $ GET http//localhost/robots.txt
    # to get the /path/to/htdocs/robots.txt

has multi document root

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(
        'HTTP::Engine::Middleware::Static' => {
            regexp  => qr{^/(robots.txt|favicon.ico|(?:css|js|img)/.+)$},
            docroot => '/path/to/htdocs/',
        },
        'HTTP::Engine::Middleware::Static' => {
            regexp  => qr{^/foo(/.+)$},
            docroot => '/foo/bar/',
        },
    );
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

    # $ GET http//localhost/css/foo.css
    # to get the /path/to/htdocs/css/foo.css

    # $ GET http//localhost/robots.txt
    # to get the /path/to/htdocs/robots.txt

    # $ GET http//localhost/foo/baz.html
    # to get the /foo/bar/baz.txt

through only the specific URL to backend

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install( 'HTTP::Engine::Middleware::Static' => {
        regexp  => qr{^/(robots.txt|favicon.ico|(?:css|img)/.+|js/(?!dynamic).+)$},
        docroot => '/path/to/htdocs/',
    });
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

    # $ GET http//localhost/js/jquery.js
    # to get the /path/to/htdocs/js/jquery.js

    # $ GET http//localhost/js/dynamic-json.js
    # to get the your application response

Will you want to set config from yaml?

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install( 'HTTP::Engine::Middleware::Static' => {
        regexp  => '^/(robots.txt|favicon.ico|(?:css|img)/.+|js/(?!dynamic).+)$',
        docroot => '/path/to/htdocs/',
    });
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

    # $ GET http//localhost/js/jquery.js
    # to get the /path/to/htdocs/js/jquery.js

    # $ GET http//localhost/js/dynamic-json.js
    # to get the your application response

=head1 DESCRIPTION

On development site, you would feed some static contents from Interface::ServerSimple, or other stuff.
This module helps that.

=head1 AUTHORS

Kazuhiro Osawa

=cut
