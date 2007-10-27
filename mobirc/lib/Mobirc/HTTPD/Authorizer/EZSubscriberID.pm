package Mobirc::HTTPD::Authorizer::EZSubscriberID;
use strict;
use warnings;
use boolean ':all';
use Carp;

sub authorize {
    my ($class, $c, $conf) = @_;

    unless ($conf->{au_subscriber_id}) {
        croak "missing au_subscriber_id";
    }

    my $subno = $c->{req}->header('x-up-subno');
    if ( $subno && $subno eq $conf->{au_subscriber_id} ) {
        return true;
    } else {
        return false;
    }
}

1;
