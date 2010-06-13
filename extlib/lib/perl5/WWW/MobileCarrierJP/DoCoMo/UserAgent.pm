package WWW::MobileCarrierJP::DoCoMo::UserAgent;
use WWW::MobileCarrierJP::Declare;
use HTML::Selector::XPath 'selector_to_xpath';
use charnames ':full';

my $URL = 'http://www.nttdocomo.co.jp/service/imode/make/content/spec/useragent/index.html';

# 不要なカラム
our @TRASH_XPATHS = (
    '//td[@rowspan]',                     # シリーズ名とか
    '//td[@class="acenter middle"]',      # シリーズ名
    selector_to_xpath('.brownLight'),     # ヘッダ
);

sub scrape {
    my $content = get($URL);
    $content =~ s{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">}{};
    my $result = scraper {
        process '//tr', 'rows[]', scraper {
            my $tree = as_tree($_);

            # 不要なカラムを削除しておく
            for my $xpath (@TRASH_XPATHS) {
                for my $node ($tree->findnodes($xpath)) {
                    $node->delete;
                }
            }

            my @cols = $tree->findnodes('//td');
            return if (scalar @cols <= 1);

            my $model = do {
                local $_ = shift @cols;
                $_ =  $_->as_text;
                s/\N{GREEK SMALL LETTER MU}/MYU/;
                s/\s?（.+//;
                s/\s//g;
                uc $_;
            };

            my $ua = sub {
                for my $col (@cols) {
                    $col = $col->as_HTML;
                    next unless $col =~ /DoCoMo/;

                    $col = (
                        grep {/DoCoMo/}
                        split m[(?:&nbsp;|<br\s*/>|\r|\n)]i, $col
                    )[0]; # XXX: 複数あるときは一番最初のがブラウザ
                    $col =~ s/ *（.+//;
                    $col =~ s/^\s*//;
                    $col =~ s/\s*$//;
                    $col =~ s/<[^><]+>//g; # remove tags
                    $col =~ s/(&#xA0.*)$//;
                    return $col;
                }
            }->();
            debug ("$model - $ua");
            debug ("------------------------------------");

            $tree = $tree->delete;

            result qw/model user_agent/;
            return {model => $model, user_agent => $ua};
        };
    }->scrape( $content )->{rows};

    @$result = grep { %$_ } @$result; # remove empty rows

    return $result;
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::DoCoMo::UserAgent - get user agent informtation from DoCoMo site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::DoCoMo::UserAgent;
    WWW::MobileCarrierJP::DoCoMo::UserAgent->scrape();

=head1 AUTHOR

Takefumi Kimura

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>,
L<http://www.nttdocomo.co.jp/service/imode/make/content/spec/useragent/index.html>

