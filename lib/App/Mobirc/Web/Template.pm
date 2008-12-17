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
        $cache->{$caller} ||= build_mt(template => $tmpl, package_name => "App::Mobirc::Web::Template::Run");
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
    use Encode qw/encode_utf8 decode_utf8/;
    use App::Mobirc::Pictogram ();

    *encoded_string = *Text::MicroTemplate::encoded_string;
    sub pictogram { encoded_string(App::Mobirc::Pictogram::pictogram(@_)) }
    sub param { decode_utf8(App::Mobirc::Web::Handler->web_context()->req->param($_[0])) }
    sub render_irc_message { encoded_string(App::Mobirc::Web::Template::IRCMessage->render_irc_message(shift)) }
    sub xml_header {
        encoded_string( join "\n",
            q{<?xml version="1.0" encoding="UTF-8" ?>},
            q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">}
        );
    }
    sub docroot {
        (App::Mobirc->context->{config}->{httpd}->{root} || '/')
    }
    sub include {
        my ($pkg, $sub, @args) = @_;
        encoded_string( "App::Mobirc::Web::Template::${pkg}"->$sub( @args ) );
    }
    sub global_context  () { App::Mobirc->context } ## no critic
    sub server          () { global_context->server } ## no critic.
}

1;
