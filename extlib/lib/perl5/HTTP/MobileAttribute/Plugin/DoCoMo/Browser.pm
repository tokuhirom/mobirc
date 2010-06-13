package HTTP::MobileAttribute::Plugin::DoCoMo::Browser;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

# http://www.nttdocomo.co.jp/service/imode/make/content/browser/index.html
#   主に2009年5月以降に発売となったブラウザキャッシュ500KBサイズ対応の
#   機種をiモードブラウザ2.0と規定します。
sub browser_version :CarrierMethod('DoCoMo') {
    my($self, $c) = @_;
    my $cs = $c->cache_size; # すごく古い機種で undef になる可能性がある
    return ($cs && $cs >= 500) ? '2.0' : '1.0';
}

1;
__END__

=encoding UTF-8

=for stopwords DoCoMo TODO CIDR

=head1 NAME

HTTP::MobileAttribute::Plugin::DoCoMo::Browser - iモードブラウザのバージョン情報

=head1 DESCRIPTION

    use HTTP::MobileAttribute plugins => [ 'DoCoMo::Browser' ];

    my $hma = HTTP::MobileAttribute->new($ua)
    if ($hma->browser_version eq '2.0') {
        # iモードブラウザ2.0 の場合の処理
    }

=head1 DESCRIPTION

2009年より発売開始になった iモードブラウザ2.0端末を判定するためのplugin です。

iモードブラウザ2.0については L<http://www.nttdocomo.co.jp/service/imode/make/content/browser/index.html> をご欄ください。

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>, L<http://www.nttdocomo.co.jp/service/imode/make/content/browser/index.html>

