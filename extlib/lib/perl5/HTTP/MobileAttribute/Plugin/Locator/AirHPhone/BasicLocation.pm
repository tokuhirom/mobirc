package HTTP::MobileAttribute::Plugin::Locator::AirHPhone::BasicLocation;
use strict;
use warnings;
use base qw( HTTP::MobileAttribute::Plugin::Locator::Base );
use Geo::Coordinates::Converter;

sub get_location {
    my ( $self, $params ) = @_;
    my ( $lat, $lng ) = $params->{ pos } =~ /^N([^E]+)E(.+)$/;
    return Geo::Coordinates::Converter->new(
        lat   => $lat || undef,
        lng   => $lng || undef,
        datum => 'tokyo',
    )->convert( 'wgs84' );
}

1;
