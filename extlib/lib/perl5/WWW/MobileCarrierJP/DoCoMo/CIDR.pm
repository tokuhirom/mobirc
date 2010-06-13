package WWW::MobileCarrierJP::DoCoMo::CIDR;
use strict;
use warnings;
use Web::Scraper;
use URI;

sub url { 'http://www.nttdocomo.co.jp/service/imode/make/content/ip/'; }

sub scrape {
    scraper {
        process
            '//div[@class="boxArea" and count(preceding-sibling::*)=2]/div/div[@class="section"]/ul[@class="normal txt" and preceding-sibling::div[1][@class="titlept03"]]/li',
                'cidr[]', [
                    'TEXT', sub {
                        m{^([0-9.]+)(/[0-9]+)};
                        +{ ip => $1, subnetmask => $2 };
                    }
                ];
    }->scrape(URI->new(__PACKAGE__->url))->{cidr};
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::DoCoMo::CIDR - get CIDR informtation from DoCoMo site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::DoCoMo::CIDR;
    WWW::MobileCarrierJP::DoCoMo::CIDR->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

