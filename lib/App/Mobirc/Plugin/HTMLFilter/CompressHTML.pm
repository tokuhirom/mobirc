package App::Mobirc::Plugin::HTMLFilter::CompressHTML;
# vim:expandtab:
use strict;
use MooseX::Plaggerize::Plugin;
use App::Mobirc::Util;

hook html_filter => sub {
    my ($self, $global_context, $c, $content) = @_;

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

    return ( $c, $content);
};

1;
__END__

=encoding utf8

=head1 NAME

App::Mobirc::Plugin::HTMLFilter::CompressHTML - compress the html filter

=head1 DESCRIPTION

compress the html filter for mobirc

=head1 AUTHOR

cho45

=head1 SEE ALSO

L<App::Mobirc>

