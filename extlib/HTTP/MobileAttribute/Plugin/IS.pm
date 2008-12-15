package HTTP::MobileAttribute::Plugin::IS;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub is_docomo: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'DoCoMo' ? 1 : 0;
}

sub is_j_phone: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'ThirdForce' ? 1 : 0;
}

sub is_vodafone: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'ThirdForce' ? 1 : 0;
}

sub is_softbank: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'ThirdForce' ? 1 : 0;
}

sub is_thirdforce: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'ThirdForce' ? 1 : 0;
}

sub is_ezweb: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'EZweb' ? 1 : 0;
}

sub is_airh_phone: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'AirHPhone' ? 1 : 0;
}

sub is_non_mobile: Method {
    my ($self, $c) = @_;
    return $c->carrier_longname eq 'NonMobile' ? 1 : 0;
}

1;
__END__

=encoding UTF-8

=for stopwords DoCoMo SoftBank EZweb AirHPhone

=head1 NAME

HTTP::MobileAttribute::Plugin::IS - is_* を定義する

=head1 METHODS

=over 4

=item is_docomo

DoCoMo 端末かどうかを判定します。

=item is_j_phone
=item is_vodafone
=item is_softbank
=item is_thirdforce

SoftBank 端末かどうかを判定します。

=item is_ezweb

EZweb 端末かどうかを判定します。

=item is_airh_phone

AirHPhone かどうかを判定します。

=item is_non_mobile

モバイル端末ではないかどうかを判定します。

=back

=head1 AUTHOR

Tokuhiro Matsuno

