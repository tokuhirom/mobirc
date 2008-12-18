package App::Mobirc::Web::Template;
# template eval. context.
use strict;
use warnings;
use Encode qw/encode_utf8 decode_utf8/;
use App::Mobirc::Pictogram ();
use Path::Class;
use URI::Escape qw/uri_escape/;

sub global_context ()   { App::Mobirc->context }
sub web_context ()      { App::Mobirc::Web::Handler->web_context }
sub server ()           { global_context->server }
sub config ()           { global_context->config }
sub req ()              { web_context->req }
sub param               { decode_utf8( req->param( $_[0] ) ) }
sub mobile_attribute () { web_context()->mobile_attribute() }

sub is_iphone {
    ( mobile_attribute()->user_agent =~ /(?:iPod|iPhone)/ ) ? 1 : 0;
}

*encoded_string = *Text::MicroTemplate::encoded_string;
sub pictogram { encoded_string(App::Mobirc::Pictogram::pictogram(@_)) }
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
sub docroot {
    (config->{global}->{root} || '/')
}
sub load_assets {
    my @path = @_;
    join '', file(config->{global}->{assets_dir}, @path)->slurp
}
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
