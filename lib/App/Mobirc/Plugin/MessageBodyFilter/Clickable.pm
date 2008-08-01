package App::Mobirc::Plugin::MessageBodyFilter::Clickable;
# vim:expandtab:
use strict;
use MooseX::Plaggerize::Plugin;
use URI::Find;
use URI::Escape;
use HTML::Entities;
use App::Mobirc::Util;
@URI::tel::ISA = qw( URI );

has accept_schemes => (
    is  => 'ro',
    isa => 'ArrayRef',
);

has http_link_string => (
    is  => 'ro',
    isa => 'Str',
);

has http_link_target => (
    is  => 'ro',
    isa => 'Str',

    default => '_blank',
);

has redirector => (
    is  => 'ro',
    isa => 'Str',
);

has au_pcsv => (
    is  => 'ro',
    isa => 'Bool',
);

has pocket_hatena => (
    is  => 'ro',
    isa => 'Bool',
);

has google_gwt => (
    is  => 'ro',
    isa => 'Bool',
);

hook message_body_filter => sub {
    my ( $self, $global_context, $text ) = @_;

    my $as = $self->accept_schemes;

    my $link_string_table = {};

    if (!$as || grep { $_ eq "tel" } @$as) {
        $text =~ s{\b(?:tel:)?(0\d{1,3})([-(]?)(\d{2,4})([-)]?)(\d{4})\b}{
            my $ret = "tel:$1$3$5";
            $link_string_table->{$ret} = $&;
            $ret;
        }eg;
    }
    if (!$as || grep { $_ eq "mailto" } @$as) {
        $text =~ s{\b(?:mailto:)?(\w[\w.+=-]+\@[\w.-]+[\w]\.[\w]{2,4})\b}{
            my $ret = "mailto:$1";
            $link_string_table->{$ret} = $&;
            $ret;
        }eg;
    }

    URI::Find->new(
        sub {
            my ( $uri, $orig_uri ) = @_;
            if ($self->accept_schemes &&
                !(grep { $_ eq $uri->scheme } @$as)) {
                return $orig_uri;
            }
            return ($self->can("process_" . $uri->scheme) || \&process_default)->($self, $uri, $orig_uri, $link_string_table);
        }
    )->find( \$text );

    return $text;
};

sub process_http {
    my ( $self, $uri, $orig_uri ) = @_;
    my $out = "";
    my $link_string = $orig_uri;

    if ( $self->http_link_string ) {
        $link_string =$self->http_link_string;
        $link_string =~ s{\$(\w+)}{
            $uri->$1;
        }eg
    }

    $link_string = encode_entities(uri_unescape($link_string),  q(<>&"));
    my $encoded_uri = encode_entities($uri, q(<>&"));

    if ( $self->redirector ) {
        $out =
        sprintf(
            '<a href="%s%s" rel="nofollow" class="url" target="%s">%s</a>',
            encode_entities($self->redirector, q(<>&")),
            $encoded_uri,
            $self->http_link_target,
            $link_string );
    } else {
        $out =
        sprintf(
            '<a href="%s" rel="nofollow" class="url" target="%s">%s</a>',
            $encoded_uri,
            $self->http_link_target,
            $link_string );
    }

    if ( $self->au_pcsv ) {
        $out .=
        sprintf(
            '<a href="device:pcsiteviewer?url=%s" rel="nofollow" class="au_pcsv" target="%s">[PCSV]</a>',
            $encoded_uri,
            $self->http_link_target );
    }

    if ( $self->pocket_hatena ) {
        $out .=
        sprintf(
            '<a href="http://mgw.hatena.ne.jp/?url=%s;noimage=0;split=1" rel="nofollow" class="pocket_hatena" target="%s">[ph]</a>',
            uri_escape($uri),
            $self->http_link_target );
    }
    if ( $self->google_gwt ) {
        $out .=
        sprintf(
            '<a href="http://www.google.co.jp/gwt/n?u=%s;_gwt_noimg=0" rel="nofollow" class="google_gwt" target="%s">[gwt]</a>',
            uri_escape($uri),
            $self->http_link_target );
    }
    return U $out;
}

sub process_default {
    my ( $self, $uri, $orig_uri, $link_string_table ) = @_;

    my $link_string = $orig_uri;
    if ( $link_string_table->{$orig_uri} ) {
        $link_string = $link_string_table->{$orig_uri};
    }
    return sprintf(
        qq{<a href="%s" rel="nofollow" class="url" target="%s">%s</a>},
        encode_entities($uri, q(<>&")),
        $self->http_link_target,
        encode_entities($link_string, q(<>&")),
    );
}

1;
