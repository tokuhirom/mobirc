package WWW::MobileCarrierJP::EZWeb::DeviceID;
use strict;
use warnings;
use URI;
use Web::Scraper;
use Carp;

my $url = 'http://www.au.kddi.com/ezfactory/tec/spec/4_4.html';

sub scrape {
    my $result;
    my $model;
    my $i=1;
    scraper {
        process '//tr[@bgcolor="#cccccc"]/td/table[@cellspacing="1"]/tr[@bgcolor="#ffffff"]/td', 'models[]', ['TEXT', sub {
            s/^\s+//;
            s/\s+$//;

            if ($i&1) {
                $model = $_;
            } else {
                push @$result,
                    +{
                    model     => $model,
                    device_id => ( $_ =~ m{/} ? [ split( '/', $_ ) ] : $_ )
                    };
            }

            ++$i;
        }];
    }->scrape(URI->new($url));

    return [
        grep { $_->{device_id} && ((ref($_->{device_id}) eq 'ARRAY') || $_->{device_id}) }
            @{ $result }
    ];
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::EZWeb::DeviceID - get DeviceID informtation from EZWeb site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::EZWeb::DeviceID;
    WWW::MobileCarrierJP::EZWeb::DeviceID->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

