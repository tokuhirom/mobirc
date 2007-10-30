package Mobirc::HTTPD::Authorizer::SoftBankID;
# vim:expandtab:
use strict;
use warnings;
use Carp;
use Mobirc::Util;

sub authorize {
    my ($class, $c, $conf) = @_;

    unless ($conf->{jphone_uid}) {
        croak "missing jphone_uid; specify your x-jphone-uid string.";
    }

    my $uid = $c->{req}->header('x-jphone-uid');
    if ( $uid && $uid eq $conf->{jphone_uid} ) {
        return true;
    } else {
        return false;
    }
}

1;
