package Mobirc::HTTPD::Filter::TelephoneNumber;
use strict;
use warnings;

sub process {
    my ( $class, $text, $conf ) = @_;

    $text =~ s!\b(0\d{1,3})([-(]?)(\d{2,4})([-)]?)(\d{4})\b!<a href="tel:$1$3$5" class="telephone_number">$1$2$3$4$5</a>!g;

    return $text;
}

1;
