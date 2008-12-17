package App::Mobirc::Web::View;
use strict;
use warnings;
use UNIVERSAL::require;

sub show {
    my ($class, $pkg, $sub, @args) = @_;
    my $klass = "App::Mobirc::Web::Template::${pkg}";
    $klass->require or die $@;
    $klass->$sub( @args );
}

1;
