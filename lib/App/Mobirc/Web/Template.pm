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
        $cache->{$caller} ||= sub {
            my $_mt = Text::MicroTemplate->new($tmpl);
            my $_code = $_mt->code;
            my $expr = << "...";
package App::Mobirc::Web::Template::Run;

sub {
    my \$args = \@_ == 1 ? \$_[0] : { \@_ };
    encoded_string((
        $_code
    )->(\@_));
}
...
            my $die_msg;
            {
                local $@;
                if (my $_builder = eval($expr)) {
                    return $_builder;
                }
                $die_msg = $_mt->_error($@, 3);
            }
            die $die_msg;
        }->();
        $cache->{$caller}->( @_ )->as_string;
    }
}

sub mt_cached_with_wrap {
    my ($pkg, $fn, $line) = caller(0);
    my $caller = join ', ', $pkg, $fn, $line;
    my $body = _mt_cached($caller, @_);
    return App::Mobirc::Web::Template::Wrapper->wrapper( $body );
}

{
    # template eval. context.
    package App::Mobirc::Web::Template::Run;
    *encoded_string = *Text::MicroTemplate::encoded_string;
    use App::Mobirc::Pictogram;
    sub param { App::Mobirc::Web::Handler->web_context()->req->param($_[0]) }
}

1;
