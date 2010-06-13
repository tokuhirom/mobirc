package HTTP::Session::State::Base;
use strict;
use warnings;
use Class::Accessor::Fast;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    no strict 'refs';
    unshift @{"${pkg}::ISA"}, "Class::Accessor::Fast";
    $pkg->mk_ro_accessors(qw/permissive/);
}

1;
