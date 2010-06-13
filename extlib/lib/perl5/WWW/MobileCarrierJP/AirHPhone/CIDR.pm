package WWW::MobileCarrierJP::AirHPhone::CIDR;
use strict;
use warnings;
use Web::Scraper;
use URI;

sub url { 'http://www.willcom-inc.com/ja/service/contents_service/create/center_info/index.html' }

sub scrape {
    scraper {
        process '//td[@align="center" and @bgcolor="white"]/font[@size="2"]', 'cidr[]', ['TEXT', sub {
                        m{^([0-9.]+)(/[0-9]+)};
                        +{ ip => $1, subnetmask => $2 };
                    }];
    }->scrape(URI->new(__PACKAGE__->url))->{cidr};
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::AirHPhone::CIDR - get CIDR informtation from willcom site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::AirHPhone::CIDR;
    WWW::MobileCarrierJP::AirHPhone::CIDR->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

