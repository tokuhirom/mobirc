package App::Mobirc::Web::View;
use strict;
use warnings;
use Template::Declare;
use Module::Find;
my @templates = useall 'App::Mobirc::Web::Template';
Template::Declare->init(roots => [@templates]);

sub show {
    my $class = shift;
    if ($_[0] =~ /^[A-Z]/) {
        my ($pkg, $sub) = (shift, shift);
        "App::Mobirc::Web::Template::${pkg}"->$sub( @_ );
    } else {
        Template::Declare->show(@_);
    }
}

1;
