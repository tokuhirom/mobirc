package App::Mobirc::Web::C::Static;
use Mouse;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Path::Class;

my $mime = {
    "css"  => "text/css",
    "js"   => "text/javascript",
    "gif"  => "image/gif",
    "png"  => "image/png",
    "jpeg" => "image/jpeg",
    "jpg"  => "image/jpeg",
};

sub dispatch_deliver {
    my ($class, $req, $args) = @_;
    my $path = $args->{filename};

    my $file = file(config->{global}->{assets_dir}, 'static', $path);
    my ($ext)  = $file->basename =~ m{\.([^.]+)$};

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => $mime->{$ext} || "application/octet-stream",
        body         => $file->openr(),
    );
}

1;
