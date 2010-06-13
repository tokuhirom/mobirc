package HTTP::MobileAttribute::Plugin::Locator::ThirdForce::BasicLocation;
# Simple Location Information
use strict;
use warnings;
use base qw( HTTP::MobileAttribute::Plugin::Locator::Base );
use Geo::Coordinates::Converter;

sub get_location {
    my $self = shift;
    my $geocode = $ENV{ HTTP_X_JPHONE_GEOCODE };
    $geocode =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
    my ( $lat, $lng, $address ) = split /\x1a/, $geocode;
    return Geo::Coordinates::Converter->new(
        lat   => _convert_point( $lat ) || undef,
        lng   => _convert_point( $lng ) || undef,
        datum => 'tokyo',
    )->convert( 'wgs84' );
}

sub _convert_point {
    my $point = shift;
    ($point = reverse split //, $point) =~ s/(..)/.$1/g;
    return join '', reverse split //, '00' . $point;
}

1;
