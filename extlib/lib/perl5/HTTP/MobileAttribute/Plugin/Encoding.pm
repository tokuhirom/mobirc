package HTTP::MobileAttribute::Plugin::Encoding;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

__PACKAGE__->depends([qw/XHTMLCompliant IS::ThirdForce/]);

sub can_display_utf8 :Method {
    my ($self, $c) = @_;
    $c->encoding =~ /utf-?8/ ? 1 : 0;
}

sub encoding_non_mobile :CarrierMethod('NonMobile',  'encoding') { 'utf-8' }
sub encoding_airh_phone :CarrierMethod('AirHPhone',  'encoding') { 'x-sjis-airh' }
sub encoding_ezweb      :CarrierMethod('EZweb',      'encoding') { 'x-sjis-ezweb-auto' }
sub encoding_thirdforce :CarrierMethod('ThirdForce', 'encoding') {
    $_[1]->is_type_3gc ? 'x-utf8-vodafone' : 'x-sjis-vodafone'
}
sub encoding_docomo     :CarrierMethod('DoCoMo',     'encoding') {
    "x-@{[ $_[1]->xhtml_compliant ? 'utf8' : 'sjis' ]}-docomo";
}

1;
__END__

=for stopwords UTF-8

=encoding UTF-8

=head1 NAME

HTTP::MobileAttribute::Plugin::Encoding - HTTP::MobileAttribute と Encode::JP::Mobile とのつなぎこみ

=head1 SYNOPSIS

    use HTTP::MobileAttribute plugins => ['Encoding'];
    use Encode;
    use Encode::JP::Mobile;

    my $ma = HTTP::MobileAttribute->new($ua);
    $ma->can_display_utf8; # => 1 or 0
    decode($ma->encoding, $r->param('foo'));

=head1 DESCRIPTION

Encode::JP::Mobile とのつなぎこみをします。

=head1 METHODS

=over 4

=item can_display_utf8

UTF-8 が表示できる端末かどうかを返します。

=item encoding

Encode::JP::Mobile で使えるエンコーディング名を返します。

=back

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>
