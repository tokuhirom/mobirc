package App::Mobirc::Web::View;
use strict;
use warnings;
use File::Spec;
use String::CamelCase qw/decamelize/;
use App::Mobirc::Util;

sub show {
    my ($class, @args) = @_;
    my $c = App::Mobirc::Web::Handler->web_context() or die "this module requires web_context!";

    my $pkg = decamelize(caller(0));
    my $action = $c->action;
    my $mt = global_context->mt;

    local $App::Mobirc::Template::REQUIRE_WRAP;
    my $res = $mt->render_file(
        File::Spec->catfile($pkg, "${action}.mt"),
        @args,
    );
    if ($App::Mobirc::Template::REQUIRE_WRAP) {
        my $res = $mt->render_file(
            File::Spec->catfile('parts/wrapper.mt')
        );
    } else {
        return $res;
    }
}

1;
