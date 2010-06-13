package WWW::MobileCarrierJP::DoCoMo::Flash;
use WWW::MobileCarrierJP::Declare;
use charnames ':full';
use Encode;
use LWP::UserAgent;
use Web::Scraper;
use URI;

my $URL = 'http://www.nttdocomo.co.jp/service/imode/make/content/spec/flash/index.html';

parse_one(
    urls => [$URL],
    xpath => '//div[position()<9]/div/div[@class="section"]',
    scraper => scraper {
        process '//h2/a/text()', 'version', ['TEXT', sub { s/^Flash Lite // }];
        process '//tr[@class="acenter"]', 'models[]', [sub {
            my $elem = $_;
            my $tree = as_tree($elem);
            $_->delete for $tree->findnodes('//td[@class="brownLight acenter middle"]');
            $_->delete for $tree->findnodes('//td[@class="acenter middle"]');
            # remove series info.

            scraper {
                process '//td[position()=1]', 'model', [
                    'TEXT', sub { s/\N{GREEK SMALL LETTER MU}/myu/; s/\（.+）// }, sub { uc }
                ];
                process '//td[position()=3]', 'standby_screen', [
                    'TEXT', sub {
                        /(\d+)×(\d+)/; +{width=>$1, height => $2}
                    }];
                process '//td[position()=2]', 'browser', [
                    'TEXT', sub {
                        my @size;
                        while (/(\d+)×(\d+)/g) {
                            push @size, +{width=>$1, height => $2}
                        }
                        \@size;
                    }];
                process '//td[position()=4]', 'working_memory_capacity', 'TEXT';
            }->scrape($tree);
        }];
    },
);

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::DoCoMo::Flash - get flash informtation from DoCoMo site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::DoCoMo::Flash;
    WWW::MobileCarrierJP::DoCoMo::Flash->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>,
L<http://www.nttdocomo.co.jp/english/service/imode/make/content/spec/flash/index.html>

