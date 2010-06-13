package HTTP::MobileAttribute::Plugin::Locator::DoCoMo::BasicLocation;
# Open iArea
use strict;
use warnings;
use base qw( HTTP::MobileAttribute::Plugin::Locator::Base );
use Geo::Coordinates::Converter;
use Geo::Coordinates::Converter::iArea;

sub get_location {
    my ( $self, $params ) = @_;

    if ($params->{LAT} && $params->{LON} && $params->{GEO}) {
        return Geo::Coordinates::Converter->new(
            lat    => $params->{LAT},
            lng    => $params->{LON},
            datum  => $params->{GEO},
        )->convert;
    } else {
        return Geo::Coordinates::Converter::iArea->get_center(
            $params->{AREACODE}
        )->convert( 'wgs84', 'dms' );
    }
}

1;
