package WWW::MobileCarrierJP::ThirdForce::CIDR;
use strict;
use warnings;
use Web::Scraper;
use URI;

sub url { 'http://creation.mb.softbank.jp/web/web_ip.html'; }

sub scrape {
    scraper {
        process q{//div[@class='contents']/table/tr[7]/td/table/tr/td/table/tr},
          'cidr[]', [
            'TEXT',
            sub {
                s/\s//g
            },
            sub {
                m{^([0-9.]+)(/[0-9]+)};
                +{ ip => $1, subnetmask => $2 };
              }
          ];
    }->scrape(URI->new(__PACKAGE__->url))->{cidr};
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::ThirdForce::CIDR - get CIDR informtation from ThirdForce site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::ThirdForce::CIDR;
    WWW::MobileCarrierJP::ThirdForce::CIDR->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

