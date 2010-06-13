package HTTP::MobileAttribute::Plugin::XHTMLCompliant;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

__PACKAGE__->depends([qw/IS::DoCoMo IS::ThirdForce/]);

sub docomo :CarrierMethod('DoCoMo', 'xhtml_compliant') {
    my ($self, $c) = @_;

    return ( $c->is_foma && $c->model !~ qr/(?:D210i|SO210i)|503i|211i|SH251i|692i|200[12]|2101V/ )
            ? 1
            : 0;
}

sub ezweb :CarrierMethod('EZweb', 'xhtml_compliant') {
    my ($self, $c) = @_;

    if ( $c->user_agent =~ /^KDDI\-/ ) {
        return 1;
    } else {
        return;
    }
}

sub non_mobile :CarrierMethod('NonMobile', 'xhtml_compliant') { 1 }

sub third_force :CarrierMethod('ThirdForce', 'xhtml_compliant') {
    my ($self, $c) = @_;
    return ( $c->is_type_w || $c->is_type_3gc ) ? 1 : 0;
}

1;
__END__

=encoding UTF-8

=for stopwords XHTML

=head1 NAME

HTTP::MobileAttribute::Plugin::XHTMLCompliant - XHTML 対応しているの?

=head1 SYNOPSIS

    use HTTP::MobileAttribute plugins => [qw/XHTMLCompliant IS::ThirdForce/];

    HTTP::MobileAttribute->new($ua)->xhtml_compliant;

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>

