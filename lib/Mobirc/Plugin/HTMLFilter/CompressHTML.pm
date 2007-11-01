package Mobirc::Plugin::HTMLFilter::CompressHTML;
# vim:expandtab:
use strict;
use warnings;
use Mobirc::Util;

sub register {
    my ($class, $global_context) = @_;

    $global_context->register_hook(
        'html_filter' => \&_html_filter_compress
    );
}

sub _html_filter_compress {
    my ($c, $content) = @_;

    use bytes;

    my $bsize = length $content;

    $content =~ s{<!--.+?-->}{}gs;
    $content =~ s{[ \t\f]+}{ }g;
    # 可読性保持のため若干めんどいことをやっている
    $content =~ s{([ \t\f]*[\r\n]+[ \t\f]*)+}{\n}g;
    $content =~ s{> ([^<])}{>$1}g;

    my $asize   = length $content;
    my $rate    = sprintf("%03.1f", 100 - ($asize / $bsize * 100));
    my $packets = sprintf("%0.1f D.%.1f", $asize / 128, ($bsize - $asize) / 128);

    DEBUG "Compress before->$bsize after->$asize $rate% packets->$packets";

    return $content;
}



1;
__END__


