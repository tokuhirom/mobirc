package HTTP::MobileAttribute::Plugin::Locator::ThirdForce::GPS;
# S!GPS
use strict;
use warnings;
use base qw( HTTP::MobileAttribute::Plugin::Locator::Base );
use Geo::Coordinates::Converter;

sub get_location {
    my ( $self, $params ) = @_;
    my ( $lat, $lng ) = $params->{ pos } =~ /^[NS]([\d\.]+)[EW]([\d\.]+)$/;
    my $datum = $params->{ geo } || 'wgs84';
    return Geo::Coordinates::Converter->new(
        lat   => $lat,
        lng   => $lng,
        datum => $datum,
    )->convert;
}

1;
