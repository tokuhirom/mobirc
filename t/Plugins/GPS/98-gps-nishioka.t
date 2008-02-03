use strict;
use warnings;
use utf8;
use Test::Base;
use App::Mobirc::Plugin::GPS::InvGeocoder::Nishioka;
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
    App::Mobirc::Plugin::GPS::InvGeocoder::Nishioka->inv_geocoder($point);
}

run_is input => 'expected';

__END__

===
--- input
datum: wgs84
lng  : 139.691706
lat  : 35.689488
--- expected: 東京都新宿区西新宿二丁目8

===
--- input
datum: wgs84
lat: 35.171289
lng: 136.882725
--- expected: 愛知県名古屋市中村区名駅一丁目1
