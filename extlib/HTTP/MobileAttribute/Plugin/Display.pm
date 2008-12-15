package HTTP::MobileAttribute::Plugin::Display;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;
use HTTP::MobileAttribute;

sub thirdforce :CarrierMethod('ThirdForce', 'display') {
    my ($self, $c) = @_;
    my $request = $c->request;

    my($width, $height) = split /\*/, $request->get('x-jphone-display');

    my($color, $depth);
    if (my $c_str = $request->get('x-jphone-color')) {
        ($color, $depth) = $c_str =~ /^([CG])(\d+)$/;
    }

    return HTTP::MobileAttribute::Plugin::Display::Display->new(+{
        width  => $width,
        height => $height,
        color  => $color eq 'C',
        depth  => $depth,
    });
}

sub ezweb :CarrierMethod('EZweb', 'display') {
    my ($self, $c) = @_;
    my $request = $c->request;

    my ( $width, $height ) = split /,/, $request->get('x-up-devcap-screenpixels');
    my $depth = ( split /,/, $request->get('x-up-devcap-screendepth') )[0];
    my $color = $request->get('x-up-devcap-iscolor');

    return HTTP::MobileAttribute::Plugin::Display::Display->new(+{
        width  => $width,
        height => $height,
        color  => ( defined $color && $color eq '1' ),
        depth  => 2**$depth,
    });
}

sub docomo :CarrierMethod('DoCoMo', 'display') {
    my ($self, $c) = @_;
    return HTTP::MobileAttribute::Plugin::Display::Display->new($self->config->{DoCoMoMap}->{ uc( $c->model ) });
}

package HTTP::MobileAttribute::Plugin::Display::Display;
use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/width height color depth/);

1;
__END__

=encoding UTF-8

=for stopwords DoCoMo

=head1 NAME

HTTP::MobileAttribute::Plugin::Display - ディスプレイサイズの情報を得る

=head1 DESCRIPTION

    use HTTP::MobileAttribute plugins => [ {
        module => 'Display',
        config => {
            DoCoMoMap => +{
                D209I => +{ color => 1 depth => 256 height => 90 width => 96 },
                # snip ...
            }
        }
    }];

    HTTP::MobileAttribute->new($ua)->display; # => instance of HTTP::MobileAttribute::Plugin::Display::Display

=head1 DESCRIPTION

'display' メソッドを呼ぶと、HTTP::MobileAttribute::Plugin::Display::Display のインスタンスをえることができます。
このオブジェクトは width, height, color, depth の 4 種類の属性をもっています。

DoCoMo は、HTTP Header 等からこの情報をうけとることができないので、データをプラグインにわたす必要があります。
この情報は、 DoCoMo からマシンリーダブルな形式では提供されていないので L<WWW::MobileCarrierJP> 等を駆使してスクレイピングする必要があります。

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>

