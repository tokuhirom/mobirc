package App::Mobirc::HTTPD::C::Static;
use Moose;
use App::Mobirc::HTTPD::C;
use App::Mobirc::Util;
use Path::Class;

sub dispatch_deliver {
    my ($class, $c, $file_name, $content_type) = @_;

    my $file = file(context->config->{global}->{assets_dir}, 'static', $file_name);

    $c->res->content_type( $content_type );
    $c->res->body( $file->openr );
}

1;
