package HTTP::MobileAttribute::Plugin::CarrierLetter;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub carrier :Method {
    my ($self, $c) = @_;

    return +{
        DoCoMo     => 'I',
        ThirdForce => 'V',
        EZweb      => 'E',
        AirHPhone  => 'H',
        NonMobile  => 'N',
    }->{ $c->carrier_longname };
}

1;
__END__

=encoding UTF-8

=head1 NAME

HTTP::MobileAttribute::Plugin::CarrierLetter - キャリヤをあらわす1文字を得る

=head1 SYNOPSIS

    use HTTP::MobileAttribute plugins => ['CarrierLetter'];

    HTTP::MobileAttribute->new($ua)->carrier; # => 'I'

=head1 DESCRIPTION

I,E,V,H,N といった1文字でキャリヤをあらわす文字を返します。

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>
