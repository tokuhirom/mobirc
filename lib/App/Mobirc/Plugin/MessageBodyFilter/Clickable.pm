package App::Mobirc::Plugin::MessageBodyFilter::Clickable;
# vim:expandtab:
use strict;
use warnings;
use URI::Find;
use URI::Escape;
@URI::tel::ISA = qw( URI );

sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        'message_body_filter' => sub { my $body = shift;  process($body, $conf) },
    );
}

sub process {
    my ( $text, $conf ) = @_;

    my $as = $conf->{accept_schemes};

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
            if ($conf->{accept_schemes} &&
                !(grep { $_ eq $uri->scheme } @$as)) {
                return $orig_uri;
            }
            return (__PACKAGE__->can("process_" . $uri->scheme) ||
                    \&process_default)->($conf, $uri, $orig_uri, $link_string_table);
        }
    )->find( \$text );

    return $text;
}

sub process_http {
    my ( $conf, $uri, $orig_uri ) = @_;
    my $out = "";
    my $link_string = $orig_uri;

    if ( $conf->{http_link_string} ) {
        $link_string =$conf->{http_link_string};
        $link_string =~ s{\$(\w+)}{
            $uri->$1;
        }eg
    }

    if ( $conf->{redirector} ) {
        $out = sprintf('<a href="%s%s" rel="nofollow" class="url">%s</a>', $conf->{redirector}, $uri, $link_string);
    } else {
        $out = qq{<a href="$uri" rel="nofollow" class="url">$link_string</a>};
    }
    if ( $conf->{au_pcsv} ) {
        $out .=
        sprintf( '<a href="device:pcsiteviewer?url=%s" rel="nofollow" class="au_pcsv">[PCSV]</a>',
            $uri );
    }
    if ( $conf->{pocket_hatena} ) {
        $out .=
        sprintf(
            '<a href="http://mgw.hatena.ne.jp/?url=%s;noimage=0;split=1" rel="nofollow" class="pocket_hatena">[ph]</a>',
            uri_escape($uri) );
    }
    if ( $conf->{google_gwt} ) {
        $out .=
        sprintf(
            '<a href="http://www.google.co.jp/gwt/n?u=%s;_gwt_noimg=0" rel="nofollow" class="google_gwt">[gwt]</a>',
            uri_escape($uri) );
    }
    return $out;
}

sub process_default {
    my ( $conf, $uri, $orig_uri, $link_string_table ) = @_;

    my $link_string = $orig_uri;
    if ( $link_string_table->{$orig_uri} ) {
        $link_string = $link_string_table->{$orig_uri};
    }
    my $out = qq{<a href="$uri" rel="nofollow" class="url">$link_string</a>};
    return $out;
}

1;
