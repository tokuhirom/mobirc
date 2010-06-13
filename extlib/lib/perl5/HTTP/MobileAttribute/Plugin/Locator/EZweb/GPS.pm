package HTTP::MobileAttribute::Plugin::Locator::EZweb::GPS;
# GPS
use strict;
use warnings;
use base qw( HTTP::MobileAttribute::Plugin::Locator::Base );
use Geo::Coordinates::Converter;

sub get_location {
    my ( $self, $params ) = @_;
    (my $lat = $params->{ lat }) =~ s/^[\-\+]//g;
    (my $lng = $params->{ lon }) =~ s/^[\-\+]//g;
    my $datum = defined $params->{ datum } && $params->{ datum } == 1 ? 'tokyo' : 'wgs84';
    my $format = defined $params->{ unit } && $params->{ unit } == 1 ? 'degree' : 'dms';
    return Geo::Coordinates::Converter->new(
        lat    => $lat,
        lng    => $lng,
        datum  => $datum,
        format => $format,
    )->convert( 'wgs84' );
}

1;
