package App::Mobirc::Web::View;
use strict;
use warnings;
use UNIVERSAL::require;
use App::Mobirc::Web::Template::Parts;

sub show {
    my ($class, $pkg, $sub, @args) = @_;
    my $klass = "App::Mobirc::Web::Template::${pkg}";
    $klass->require or die $@;
    $klass->$sub( @args );
}

1;
