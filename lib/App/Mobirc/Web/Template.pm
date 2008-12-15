package App::Mobirc::Web::Template;
use strict;
use warnings;
use App::Mobirc;
use Text::MicroTemplate qw/build_mt/;

sub import {
    my $class = shift;
    my $pkg = caller(0);
    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/mt_cached/) {
            *{"${pkg}::${meth}"} = *{"${class}::${meth}"};
        }
    }
}

{
    my $cache;
    sub mt_cached {
        my $tmpl = shift;
        my ($pkg, $fn, $line) = caller(0);
        my $caller = join '', $pkg, $fn, $line;
        $cache->{$caller} ||= build_mt($tmpl);
        $cache->{$caller}->( @_ )->as_string;
    }
}

1;
