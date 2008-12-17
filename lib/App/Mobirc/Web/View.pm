package App::Mobirc::Web::View;
use strict;
use warnings;
use UNIVERSAL::require;
use File::Spec;
use String::CamelCase qw/decamerize/;

sub show {
    my ($class, @args) = @_;
    my $c = App::Mobirc::Web::Handler->context() or die "this module requires web_context!";

    my $pkg = decamerize(caller(0));
    my $action = $c->action;
    my $mt = App::Mobirc->context->mt;

    local $App::Mobirc::Template::REQUIRE_WRAP;
    my $res = $mt->render_file(
        File::Spec->catfile($pkg, "${action}.mt"),
        @args,
    );
    if ($App::Mobirc::Template::REQUIRE_WRAP) {
        my $res = $mt->render_file(
            File::Spec->catfile('wrapper/wrapper.mt')
        );
    } else {
        return $res;
    }
}

1;
