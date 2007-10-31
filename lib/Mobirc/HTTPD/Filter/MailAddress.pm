package Mobirc::HTTPD::Filter::MailAddress;
use strict;
use warnings;

sub process {
    my ( $class, $text, $conf ) = @_;

    $text =~ s!(?:mailto:)?\b(\w[\w.+=-]+\@[\w.-]+[\w]\.[\w]{2,4})\b!mailto:$1!g;

    return $text;
}

1;
