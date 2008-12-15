package App::Mobirc::Web::Template;
use strict;
use warnings;
use App::Mobirc;
use Text::MicroTemplate qw/build_mt/;
use App::Mobirc::Web::Template::Wrapper;

sub import {
    my $class = shift;
    my $pkg = caller(0);
    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/mt_cached mt_cached_with_wrap/) {
            *{"${pkg}::${meth}"} = *{"${class}::${meth}"};
        }
    }
}

{
    my $cache;
    sub mt_cached {
        my ($pkg, $fn, $line) = caller(0);
        my $caller = join ', ', $pkg, $fn, $line;
        _mt_cached($caller, @_);
    }

    sub _mt_cached {
        my $caller = shift;
        my $tmpl = shift;
        $cache->{$caller} ||= build_mt($tmpl);
        $cache->{$caller}->( @_ )->as_string;
    }
}

sub mt_cached_with_wrap {
    my ($pkg, $fn, $line) = caller(0);
    my $caller = join ', ', $pkg, $fn, $line;
    my $body = _mt_cached($caller, @_);
    return App::Mobirc::Web::Template::Wrapper->wrapper( $body );
}

1;
