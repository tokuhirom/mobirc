package Mobirc::HTTPD::Filter::URL;
# vim:expandtab:
use strict;
use warnings;
use URI::Find;
use URI::Escape;
@URI::tel::ISA = qw( URI );

sub process {
    my ( $class, $text, $conf ) = @_;

    URI::Find->new(
        sub {
            my ( $uri, $orig_uri ) = @_;
            if ($conf->{accept_schemes} &&
                !(grep { $_ eq $uri->scheme } @{ $conf->{accept_schemes} })) {
                return $orig_uri;
            }
            return (__PACKAGE__->can("process_" . $uri->scheme) ||
                    \&process_default)->($class, $conf, $uri, $orig_uri);
        }
    )->find( \$text );

    return $text;
}

sub process_http {
    my ( $class, $conf, $uri, $orig_uri ) = @_;
    my $out = "";
    if ( $conf->{redirector} ) {
        $out = sprintf('<a href="%s%s" rel="nofollow" class="url">%s</a>', $conf->{redirector}, $uri, $uri);
    } else {
        $out = qq{<a href="$uri" rel="nofollow" class="url">$orig_uri</a>};
    }
    if ( $conf->{au_pcsv} ) {
        $out .=
        sprintf( '<a href="device:pcsiteviewer?url=%s" rel="nofollow" class="au_pcsv">[PCSV]</a>',
            $uri );
    }
    if ( $conf->{pocket_hatena} ) {
        $out .=
        sprintf(
            '<a href="http://mgw.hatena.ne.jp/?url=%s&noimage=0&split=1" rel="nofollow" class="pocket_hatena">[ph]</a>',
            uri_escape($uri) );
    }
    return $out;
}

sub process_default {
    my ( $class, $conf, $uri, $orig_uri ) = @_;
    my $out = qq{<a href="$uri" rel="nofollow" class="url">$orig_uri</a>};
    return $out;
}

1;
