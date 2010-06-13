package HTTP::MobileAttribute;
use strict;
use warnings;
our $VERSION = '0.21';
use 5.008001;
use HTTP::MobileAttribute::Request;
use HTTP::MobileAttribute::CarrierDetector;
use UNIVERSAL::require;

# XXX: This really affects the first time H::MobileAttribute gets loaded
sub import {
    my $class   = shift;
    my %args    = @_;
    my $plugins = delete $args{plugins} || [ 'Core' ];

    if (ref $plugins ne 'ARRAY') {
        $plugins = [ $plugins ];
    }
    $class->load_plugins(@$plugins);
}

sub carriers { qw/DoCoMo AirHPhone ThirdForce EZweb NonMobile/ }

BEGIN {
    for (carriers()) {
        "HTTP::MobileAttribute::Agent::$_"->use or die $@;
    }
};

sub new {
    my ($class, $stuff) = @_;

    my $request = HTTP::MobileAttribute::Request->new($stuff);

    # XXX carrier name detection is actually simple, so instead of
    # going through the hassle of doing Detector->detect, we simply
    # create a function that does the right thing and use it
    my $carrier_longname = HTTP::MobileAttribute::CarrierDetector::detect($request->get('User-Agent'));

    my $self = $class->agent_class($carrier_longname)->new({
        request          => $request,
        carrier_longname => $carrier_longname,
    });
    $self->parse;
    return $self;
}

sub agent_class { 'HTTP::MobileAttribute::Agent::' . $_[1] }

sub load_plugins {
    my ($class, @plugins) = @_;

    for my $carrier (carriers()) {
        $class->agent_class($carrier)->load_plugins(@plugins);
    }
}


1;
__END__

=encoding UTF-8

=for stopwords aaaatttt gmail dotottto commmmm Kazuhiro Osawa Plaggable DoCoMo ThirdForce Vodafone docs Daisuke Maki

=head1 NAME

HTTP::MobileAttribute - Yet Another HTTP::MobileAgent

=head1 SYNOPSIS

  use HTTP::MobileAttribute;

  HTTP::MobileAttribute->load_plugins(qw/Flash Image CarrierName/);

  my $agent = HTTP::MobileAttribute->new;
  $agent->is_supported_flash();
  $agent->is_supported_gif();

  # in apache2
  my $agent = HTTP::MobileAttribute->new($r->headers_in);

=head1 WARNINGS

WE ARE NOW TESTING THE CONCEPT.

DO NOT USE THIS MODULE.

=head1 DESCRIPTION

HTTP::MobileAttribute is Plaggable version of HTTP::MobileAgent.

っていうか、まあ日本人しかつかわないだろうから日本語で docs かくね。

現時点では、とりあえずキャリヤ判定がデキルッポイ。

=head1 コンセプト

    - キャリヤ判別もプラグァーブル
    - トニカクぷらぐぁーぶる
    - HTTP::MobileAgent とできるだけ互換性をもたす。かも。

=head1 非互換メモ

当たり前のことながら、$agent->isa はつかえないね。

carrier_longname が Vodafone じゃなくて ThirdForce を返すよ

=head2 廃止したメソッド

可能な限り、HTTP::MobileAgent とメソッド名に互換性を持たせてある。
ただし、今時どうみてもつかわんだろうというようなものは削ってある。

具体的には

    DoCoMo: series

なんだけど、つかってないよね?もし使ってる人いたら実装してください。

あと、 DoCoMo の、たぶん当時はつかってたんだろうけど今はつかってないっぽいものも消してある(もともとつけられるからつけただけなのかもしらんけど)。

    vendor
    cache_size
    html_version

=head1 気になってること

=head2 メモリつかいすぎ疑惑

まあ、たしょうメモリはいっぱいつかうよね。

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom aaaatttt gmail dotottto commmmmE<gt>

Kazuhiro Osawa

Daisuke Maki

=head1 THANKS TO

    Tatsuhiko Miyagawa(original author of HTTP::MobileAgent)
    Satoshi Tanimoto
    Yoshiki Kurihara(Current mentainer of HTTP::MobileAgent)
    ZIGUZAGU
    nekokak

=head1 SEE ALSO

L<HTTP::MobileAgent>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
