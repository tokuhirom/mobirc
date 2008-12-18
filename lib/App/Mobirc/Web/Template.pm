package App::Mobirc::Web::Template;
# template eval. context.
use strict;
use warnings;
use Encode qw/encode_utf8 decode_utf8/;
use App::Mobirc::Pictogram ();
use Path::Class;
use Devel::Caller::Perl () ;

our $_MT;
our $_MT_T;

*encoded_string = *Text::MicroTemplate::encoded_string;
sub pictogram { encoded_string(App::Mobirc::Pictogram::pictogram(@_)) }
sub global_context  () { App::Mobirc->context   } ## no critic
sub web_context () { App::Mobirc::Web::Handler->web_context } ## no critic
sub param { decode_utf8(web_context()->req->param($_[0])) }
sub xml_header {
    encoded_string( join "\n",
        q{<?xml version="1.0" encoding="UTF-8" ?>},
        q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">}
    );
}
sub include {
    my ($path, @args) = @_;
    App::Mobirc->context->mt->render_file(
        "${path}.mt",
        @args,
    );
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
sub wrap (&) {
    my $code  = shift;
    global_context->mt->wrapper_file('parts/wrapper.mt')->($code);
}

sub strip_nl (&) {
    my $code  = shift;
    global_context->mt->filter(sub {
        s/^\s+//smg;
        s/[\r\n]//g;
    })->($code);
}

1;
