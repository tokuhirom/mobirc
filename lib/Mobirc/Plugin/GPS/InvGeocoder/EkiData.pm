package Mobirc::Plugin::GPS::InvGeocoder::EkiData;
use strict;
use warnings;
use Geo::Coordinates::Converter;
use LWP::UserAgent;
use XML::Simple;
use Encode;

sub inv_geocoder {
    my ($class, $point) = @_;

    my $geo = Geo::Coordinates::Converter->new(point => $point);
    my $p = $geo->convert('degree', 'wgs84');

    my $url = "http://www.ekidata.jp/api/s.php?lon=@{[ $p->lng ]}&lat=@{[ $p->lat ]}";

    my $ua = LWP::UserAgent->new;
    my $res = $ua->get($url);
    if ($res->is_success) {
        my $stations = XML::Simple::XMLin($res->content)->{station};
        my $station = (ref($stations) eq 'ARRAY') ? $stations->[0] : $stations;
        return $station->{line_name} . $station->{station_name};
    } else {
        warn "OOPS";
        return "ERROR OCCURED :" . $res->status_line;
    }
}

1;
