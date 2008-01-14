package Mobirc::Plugin::GPS::InvGeocoder::Nishioka;
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

    my $url = "http://nishioka.sakura.ne.jp/google/ws.php?lon=@{[ $p->lng ]}&lat=@{[ $p->lat ]}&format=simple";

    my $ua = LWP::UserAgent->new;
    my $res = $ua->get($url);
    if ($res->is_success) {
        return XML::Simple::XMLin($res->content)->{point}->{address};
    } else {
        warn "OOPS";
        return "ERROR OCCURED :" . $res->status_line;
    }
}

1;
__END__

=head1 AUTHOR

Tokuhiro Matsuno.

=head1 SEE ALSO

L<http://www.knya.net/archives/2005/07/rest.html>
