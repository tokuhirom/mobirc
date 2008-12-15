package HTTP::MobileAttribute::Plugin::CIDR;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

use Net::CIDR::MobileJP;

__PACKAGE__->depends([qw/CarrierLetter/]);

sub init {
    my($self, $c) = @_;
    $self->{cidr} = Net::CIDR::MobileJP->new($self->config->{cidr});
}

sub reload_cidr :Method {
    my($self, $c, $cidr) = @_;
    $self->{cidr} = Net::CIDR::MobileJP->new($cidr);
    return;
}

sub isa_cidr :Method {
    my($self, $c, $ip) = @_;
    ($c->carrier eq $self->{cidr}->get_carrier($ip));
}

1;
__END__

=encoding UTF-8

=for stopwords DoCoMo TODO CIDR

=head1 NAME

HTTP::MobileAttribute::Plugin::CIDR - キャリヤのCIDRの含まれるIPアドレスかを調べる

=head1 DESCRIPTION

    use HTTP::MobileAttribute plugins => [ {
        module => 'CIDR',
        config => {
            cidr => 'net-cidr-mobile-jp.yaml',
        }
    }];

    my $hma = HTTP::MobileAttribute->new($ua)
    if ($hma->isa_cidr('222.7.56.248')) {
        # キャリヤの CIDR に含まれたIPアドレスだよ
    }

例えば運用中のアプリケーションを止めずにCIDRの定義を reload することができる。

    $hma->reload_cidr('new-cidr.yaml');


=head1 DESCRIPTION

'isa_cidr'メソッドに調べたいIPアドレスを引数として呼ぶと、L<Net::CIDR::MobileJP>を使って、キャリヤの CIDR に含まれるIPアドレスかが分かります。

各キャリヤの CIDR 情報はマシンリーダブルな形式では提供されていないのでL<Net::CIDR::MobileJP>に付属するnet-cidr-mobilejp-scraper.plを用いて各キャリアの CIDR 情報をまとめたYAMLファイルを作る必要があります。

=head1 TODO

isa_cidrに引数を与えなくても判別できるようにしたいが、Catalystなどの場合だと $c->req->headers の中に REMOTE_ADDR が入らないケースがあるので、どうしようか考え中。

=head1 AUTHORS

Kazuhiro Osawa

=head1 SEE ALSO

L<HTTP::MobileAttribute>, L<Net::CIDR::MobileJP>

