package WWW::MobileCarrierJP::EZWeb::BREW;
use strict;
use warnings;
use Web::Scraper;
use URI;

my $url = 'http://www.au.kddi.com/ezfactory/service/brew.html';

sub scrape {
    my @result;
    my $model;
    scraper {
        process '//div[@class="TableText"]/..', 'cols[]', sub {
            if ($model) {
                push @result, +{ model => $model, version => $_->as_trimmed_text };
                $model = undef;
            } else {
                $model = $_->as_trimmed_text;
            }
        };
    }->scrape(URI->new($url));

    \@result;
}

1;

__END__

=head1 NAME

WWW::MobileCarrierJP::EZWeb::BREW - get BREW informtation from EZWeb site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::EZWeb::BREW;
    WWW::MobileCarrierJP::EZWeb::BREW->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

