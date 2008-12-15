package HTTP::MobileAttribute::Plugin::UserID;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

__PACKAGE__->depends([qw/IS IS::ThirdForce/]);

sub thirdforce :CarrierMethod('ThirdForce', 'user_id') {
    my ($self, $c) = @_;
    my $id;
    $id = $c->serial_number if $self->config->{fallback};
    $c->request->get('x-jphone-uid') || $id;
}

sub ezweb :CarrierMethod('EZweb', 'user_id') {
    my ($self, $c) = @_;
    $c->request->get('x-up-subno');
}

sub docomo_default :CarrierMethod('DoCoMo', 'user_id') {
    my ($self, $c, $req) = @_;
    my $id;
    if ($self->config->{fallback}) {
        $id = $c->serial_number;
        $id .= ',' . $c->card_id if $self->config->{fallback_with_cardid} && $c->card_id;
    }
    $self->docomo_uid($c, $req) || $self->docomo_guid($c) || $id;
}

sub docomo_uid :CarrierMethod('DoCoMo', 'uid') {
    my ($self, $c, $req) = @_;
    my $uid;
    $uid = $req->param('uid') if $req;
    $c->request->get('x-docomo-uid') || $uid;
}

sub docomo_guid :CarrierMethod('DoCoMo', 'guid') {
    my ($self, $c) = @_;
    $c->request->get('x-dcmguid');
}

sub supportes_user_id :Method {
    my ($self, $c) = @_;

    return ( $c->is_ezweb || ($c->is_thirdforce && !$c->is_type_c) || $c->is_docomo )  ? 1 : 0;
}

1;
__END__

$r->param('uid') L<Apache::DoCoMoUID>

=for stopwords FOMA guid fallback

=encoding UTF-8

=for stopwords DoCoMo

=head1 NAME HTTP::MobileAttribute::Plugin::UserID - ユーザIDや端末IDを返す

=head1 DESCRIPTION

    use HTTP::MobileAttribute plugins => [qw/ UserID /];
    my $hma = HTTP::MobileAttribute->new($ua);
    $hma->id;

ユーザIDが送信されていなければ端末IDを返す

    use HTTP::MobileAttribute plugins => [
        'Core',
        +{
            module => 'ID',
            config => { fallback => 1 },
        }
    ];
    my $hma = HTTP::MobileAttribute->new($ua);
    $hma->id;

FOMA の場合にはカードIDも付与する

    use HTTP::MobileAttribute plugins => [
        'Core',
        +{
            module => 'ID',
            config => { fallback => 1, fallback_with_cardid => 1 },
        }
    ];
    my $hma = HTTP::MobileAttribute->new($ua);
    $hma->id;

クエリパラメータから uid を取得する。

    $hma->id( $c->req );

uidのみを直接取得する(DoCoMoのみ)

    $hma->uid;
    $hma->uid( $c->req );

guidのみを直接取得する(DoCoMoのみ)

    $hma->guid;

=head1 DESCRIPTION

'id'メソッド呼ぶと、キャリヤより送信されてくるユーザIDを取得できます。

ユーザの設定によりキャリアからユーザIDが送られてこないときには undef が変えされますが、 load_plugin 時に fallback => 1 と config を追加すると、ユーザIDが取れないときには端末IDを取得するようになります。
また、 FOMA の時には fallback_with_cardid => 1 と設定すると '端末ID,カードID'という形式でIDが戻されます。

fallback オプションを利用すると、ユーザIDなのか端末IDなのかを気にしたい時に煩雑になりがちなので、 fallback オプションの利用は控えた方が良いでしょう。

なおL<Apache::DoCoMoUID>などにより、 HTTP_X_DOCOMO_UID 環境変数が設定されている場合には uid の取得は HTTP_X_DOCOMO_UID を利用します。

DoCoMo の場合のみ、IDを取得する優先順位は uid -> guid -> fallback の順になります。

=head1 AUTHORS

Kazuhiro Osawa

=head1 SEE ALSO

L<HTTP::MobileAttribute>
