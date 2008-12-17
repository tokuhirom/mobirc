package App::Mobirc::Web::View;
use strict;
use warnings;
use File::Spec;
use String::CamelCase qw/decamelize/;
use App::Mobirc::Util;

sub show {
    my ($class, @args) = @_;
    my $c = App::Mobirc::Web::Handler->web_context() or die "this module requires web_context!";

    my $fname = do {
        my $pkg = decamelize($c->controller);
        my $action = $c->action;
        File::Spec->catfile($pkg, "${action}.mt");
    };
    my $mt = global_context->mt;

    local $App::Mobirc::Template::REQUIRE_WRAP;
    my $res = $mt->render_file(
        $fname,
        @args,
    );
    if ($App::Mobirc::Template::REQUIRE_WRAP) {
        $res = $mt->render_file(
            File::Spec->catfile('parts', 'wrapper.mt'),
            $res
        );
    }
    $res->as_string;
}

1;
