#!/usr/bin/perl -w
use strict;
use warnings;

use YAML;

use WWW::MobileCarrierJP 0.19;
use WWW::MobileCarrierJP::DoCoMo::CIDR;
use WWW::MobileCarrierJP::EZWeb::CIDR;
use WWW::MobileCarrierJP::AirHPhone::CIDR;
use WWW::MobileCarrierJP::ThirdForce::CIDR;

&main;exit;

sub short_name_for {
    my $carrier = shift;
    +{
        DoCoMo     => 'I',
        EZWeb      => 'E',
        AirHPhone  => 'H',
        ThirdForce => 'V',
    }->{$carrier};
}

sub scrape {
    my $result;
    for my $carrier (qw/DoCoMo EZWeb AirHPhone ThirdForce/) {
        my $class = "WWW::MobileCarrierJP::${carrier}::CIDR";
        my $dat = $class->scrape;
        $result->{short_name_for($carrier)} = [map { "$_->{ip}$_->{subnetmask}" } @$dat];
    }
    return $result;
}

sub main {
    print YAML::Dump(scrape());
}

__END__

=head1 SYNOPSIS

    $ net-cidr-mobilejp-scraper.pl

=head2 DESCRIPTION

scraping script for Net::CIDR::MobileJP.

