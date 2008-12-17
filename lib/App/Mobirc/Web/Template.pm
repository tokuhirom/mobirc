package App::Mobirc::Web::Template;
use strict;
use warnings;
use App::Mobirc;
use Text::MicroTemplate qw/build_mt/;

our $REQUIRE_WRAP;

sub import {
    my $class = shift;
    my $pkg = caller(0);
    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/mt_cached mt_cached/) {
            *{"${pkg}::${meth}"} = *{"${class}::${meth}"};
        }
    }
}

{
    my $cache;
    sub _mt_cached {
        my $caller = shift;
        my $tmpl = shift;
        local $REQUIRE_WRAP;
        $cache->{$caller} ||= build_mt(template => $tmpl, package_name => "App::Mobirc::Web::Template::Run");
        my $res = $cache->{$caller}->( @_ )->as_string;
        if ($REQUIRE_WRAP) {
            return App::Mobirc::Web::View->show('Wrapper', 'wrapper', $res);
        } else {
            return $res;
        }
    }
}

sub mt_cached {
    my ($pkg, $fn, $line) = caller(0);
    my $caller = join ', ', $pkg, $fn, $line;
    _mt_cached($caller, @_);
}

{
    # template eval. context.
    package App::Mobirc::Web::Template::Run;
    use Encode qw/encode_utf8 decode_utf8/;
    use App::Mobirc::Pictogram ();
    use Path::Class;

    *encoded_string = *Text::MicroTemplate::encoded_string;
    sub pictogram { encoded_string(App::Mobirc::Pictogram::pictogram(@_)) }
    sub global_context  () { App::Mobirc->context   } ## no critic
    sub web_context () { App::Mobirc::Web::Handler->web_context } ## no critic
    sub param { decode_utf8(web_context()->req->param($_[0])) }
    sub render_irc_message { include('IRCMessage', 'render_irc_message', shift) }
    sub xml_header {
        encoded_string( join "\n",
            q{<?xml version="1.0" encoding="UTF-8" ?>},
            q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">}
        );
    }
    sub include {
        my ($pkg, $sub, @args) = @_;
        encoded_string( "App::Mobirc::Web::Template::${pkg}"->$sub( @args ) );
    }
    sub server          () { global_context->server } ## no critic.
    sub config          () { global_context->config } ## no critic.
    sub docroot {
        (config->{httpd}->{root} || '/')
    }
    sub load_assets {
        my @path = @_;
        join '', file(config->{global}->{assets_dir}, @path)->slurp
    }
    sub mobile_attribute () { web_context()->mobile_attribute() }
    sub is_iphone { (mobile_attribute()->user_agent =~ /(?:iPod|iPhone)/) ? 1 : 0 }
    sub require_wrap { $App::Mobirc::Template::REQUIRE_WRAP++ };
}

1;
