package App::Mobirc::Plugin::Authorizer::SoftBankID;
# vim:expandtab:
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
