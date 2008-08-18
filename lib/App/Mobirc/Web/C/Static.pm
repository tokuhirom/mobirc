package App::Mobirc::Web::C::Static;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Path::Class;

sub dispatch_deliver {
    my ($class, $req, $args) = @_;
    my $path = $args->{filename};
    die "invalid path: $path" unless $path =~ m{^[a-z0-9-]+\.(?:css|js)$};

    my $file = file(context->config->{global}->{assets_dir}, 'static', $path);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => ($path =~ /\.css$/ ? 'text/css' : 'text/javascript' ),
        body         => $file->openr(),
    );
}

1;
