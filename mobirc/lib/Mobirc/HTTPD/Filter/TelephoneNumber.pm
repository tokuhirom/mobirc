package Mobirc::HTTPD::Filter::TelephoneNumber;
use strict;
use warnings;

sub process {
    my ( $class, $text, $conf ) = @_;

    $text =~ s!\b(?:tel:)?(0\d{1,3})([-(]?)(\d{2,4})([-)]?)(\d{4})\b!tel:$1$3$5!g;

    return $text;
}

1;
