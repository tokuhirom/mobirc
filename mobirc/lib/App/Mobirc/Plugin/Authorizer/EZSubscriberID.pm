package App::Mobirc::Plugin::Authorizer::EZSubscriberID;
use strict;
use warnings;
use Carp;
use App::Mobirc::Util;

sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        'authorize' => sub { my $c = shift;  _authorize($c, $conf) },
    );
}

sub _authorize {
    my ( $c, $conf ) = @_;

    DEBUG __PACKAGE__;

    unless ($conf->{au_subscriber_id}) {
        croak "missing au_subscriber_id";
    }

    my $subno = $c->{req}->header('x-up-subno');
    if ( $subno && $subno eq $conf->{au_subscriber_id} ) {
        DEBUG "SUCESS AT EZSubscriberID";
        return true;
    } else {
        return false;
    }
}

1;
