package HTTP::MobileAttribute::Attribute::CarrierMethod;
use strict;
use warnings;
use base 'Class::Component::Attribute';

sub register {
    my ( $class, $plugin, $c, $method, $param, $code ) = @_;

    if (ref $param) {
        return unless $c =~ $param->[0];
        $c->register_method( $param->[1] => { plugin => $plugin, method => $method } );
    } else {
        return unless $c =~ $param;
        $c->register_method( $method => $plugin );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

HTTP::MobileAttribute::Attribute::CarrierMethod - キャリヤ専用メソッド定義用アトリビュート

=head1 SYNOPSIS

    sub foo :CarrierMethod('DoCoMo') { }
    sub bar :CarrierMethod('EZweb', 'method_name') { }

=head1 DESCRIPTION

HTTP::MobileAttribute::Plugin::* において、キャリヤごとのメソッドを定義するためにつかいます。

第1引数は、キャリヤ名です。

第2引数はメソッド名です。これは省略可能であり、省略した場合には、実メソッド名でコンテキストクラスにメソッド定義されます。

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>

