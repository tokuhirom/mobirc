package App::Mobirc::Plugin::GPS::InvGeocoder::Null;
use strict;
use warnings;
use Geo::Coordinates::Converter;

sub inv_geocoder {
    my ($class, $point) = @_;

    my $geo = Geo::Coordinates::Converter->new(point => $point);
    my $p = $geo->convert('dms', 'wgs84');
    
    "Lat: @{[ $p->lat ]}, Lng: @{[ $p->lng ]}";
}

1;
