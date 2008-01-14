use strict;
use warnings;
use utf8;
use Test::Base;
use Mobirc::Plugin::GPS::InvGeocoder::EkiData;
use Geo::Coordinates::Converter;

plan tests => 1*blocks;

filters {
    input => [qw/yaml point inv_geocoder/],
};

sub point {
    my $input = shift;
    my $geo = Geo::Coordinates::Converter->new(%{$input});
    $geo->convert('wgs84', 'degree');
}

sub inv_geocoder {
    my $point = shift;
    Mobirc::Plugin::GPS::InvGeocoder::EkiData->inv_geocoder($point);
}

run_is input => 'expected';

__END__

===
--- input
datum: wgs84
lng  : 139.691706
lat  : 35.689488
--- expected: 都営大江戸線都庁前

===
--- input
datum: wgs84
lat: 35.171289
lng: 136.882725
--- expected: 名古屋市営地下鉄桜通線名古屋
