package WWW::MobileCarrierJP::DoCoMo::HTMLVersion;
use WWW::MobileCarrierJP::Declare;
use HTML::TableExtract;
use charnames ':full';

parse_one(
    urls => ["http://www.nttdocomo.co.jp/service/imode/make/content/spec/useragent/"],
    xpath => '//div[@class="titlept01"]/../../div[@class="section"]',
    content_filter => sub {
        local $_ = shift;
        # hmmm. libxml is strange.
        s{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">}{};
        $_;
    },
    scraper => scraper {
        process 'h2.title', 'version',
            [ 'TEXT', sub { s/^iモード対応HTML(\d\.\d).*$/$1/ } ];
        return if result->{version} !~ /^[0-9.]+$/;

        my $tree = $_->clone;
        $_->delete for $tree->findnodes('//td[contains(@class, "brownLight")]');
        $_->delete for $tree->findnodes('//a');
        my @models;
        for my $table ($tree->findnodes('//table')) {
            my $te = HTML::TableExtract->new();
            $te->parse($table->as_HTML);
            for my $row ($te->rows) {
                local $_ = $row->[1] || $row->[0];
                s/\x{a0}.*$//; # cut after space
                s/\n//g;
                s/（.*//;
                s/\N{GREEK SMALL LETTER MU}/myu/;
                push @models, $_;
            }
        }

        return +{ models => \@models, version => result->{version} };
    },
);

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::DoCoMo::HTMLVersion - get HTMLVersion informtation from DoCoMo site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::DoCoMo::HTMLVersion;
    WWW::MobileCarrierJP::DoCoMo::HTMLVersion->scrape();

=head1 NOTE

iモードブラウザ2.0 以後、HTML Version という概念がなくなった(ようにみえる)ので、注意が必要です。このモジュールでは、i-modeブラウザ2.0な端末かどうかという情報は出力していません。

cache size が 500kb 以上のものかどうかをみて、i-mode browser 2.0 対応端末かどうかを判断してください。

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

