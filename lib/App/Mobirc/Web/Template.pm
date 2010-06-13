package App::Mobirc::Web::Template;
# template eval. context.
use strict;
use warnings;
use utf8;
use Encode qw/encode_utf8 decode_utf8/;
use App::Mobirc::Pictogram ();
use Path::Class;
use URI::Escape qw/uri_escape/;
use App::Mobirc::Web::Base;
use Unicode::EastAsianWidth;

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
    for my $plugin (@{ config->{plugin} }) {
        if ($plugin->{module} eq "DocRoot") {
            return ($plugin->{config}->{root} || '/');
        }
    }
    return '/';
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

sub visual_width {
    local $_ = shift;

    my $ret = 0;
    while (/(?:(\p{InFullwidth}+)|(\p{InHalfwidth}+))/g) {
        $ret += $1 ? length($1) * 2 : length($2)
    }
    $ret;
}

sub visual_trim {
    local $_ = shift;
    my $limit = shift;

    my $cnt = 0;
    my $ret = '';
    while (/(?:(\p{InFullwidth})|(\p{InHalfwidth}))/g) {
        if ($1) {
            if ($cnt+2 <= $limit) {
                $ret .= $1;
                $cnt += 2;
            } else {
                last;
            }
        } else {
            if ($cnt+1 <= $limit) {
                $ret .= $2;
                $cnt += 1;
            } else {
                last;
            }
        }
    }
    $ret;
}

1;
