package Mobirc::HTTPD::Filter::MailAddress;
use strict;
use warnings;

sub process {
    my ( $class, $text, $conf ) = @_;

    $text =~ s!\b(\w[\w.+=-]+\@[\w.-]+[\w]\.[\w]{2,4})\b!<a href="mailto:$1" class="mail_address">$1</a>!g;

    return $text;
}

1;
