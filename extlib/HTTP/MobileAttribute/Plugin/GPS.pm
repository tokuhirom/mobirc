package HTTP::MobileAttribute::Plugin::GPS;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

our $DoCoMoGPSModels = { map { $_ => 1 } qw(F661i F505iGPS) };

sub is_gps : CarrierMethod('DoCoMo') {
    my ($self, $c) = @_;
    return exists $DoCoMoGPSModels->{ $c->model };
}

1;
