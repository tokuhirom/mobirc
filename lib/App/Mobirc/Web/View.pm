package App::Mobirc::Web::View;
use strict;
use warnings;
use UNIVERSAL::require;
use App::Mobirc::Web::Template::Parts;
use App::Mobirc::Web::Template::Wrapper;

sub show {
    my ($class, $pkg, $sub, @args) = @_;
    $App::Mobirc::Web::Handler::CONTEXT or die "this module requires web_context!";
    my $klass = "App::Mobirc::Web::Template::${pkg}";
    $klass->require or die $@;
    $klass->$sub( @args );
}

1;
