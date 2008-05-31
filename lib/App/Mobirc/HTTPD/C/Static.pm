package App::Mobirc::HTTPD::C::Static;
use Moose;
use App::Mobirc::HTTPD::C;
use App::Mobirc::Util;
use Path::Class;

sub dispatch_deliver {
    my ($class, $c, $args) = @_;
    my $path = $args->{filename};
    die "invalid path: $path" unless $path =~ m{^[a-z0-9]+\.(?:css|js)$};

    my $file = file(context->config->{global}->{assets_dir}, 'static', $path);

    $c->res->content_type( $path =~ /\.css$/ ? 'text/css' : 'text/javascript' );
    $c->res->body( $file->openr );
}

1;
