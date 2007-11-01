use strict;
use warnings;
use Test::Base;
use Mobirc::Plugin::MessageBodyFilter::Clickable;

plan tests => 1*blocks;

filters {
    input => ['yaml', 'clickable' ]
};

sub clickable {
    my $x = shift;
    Mobirc::Plugin::MessageBodyFilter::Clickable::process( $x->{text}, $x->{conf} );
}

run_is input => 'expected';

__END__

=== basic
--- input
text: http://d.hatena.ne.jp/
conf: ~
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url">http://d.hatena.ne.jp/</a>

=== basic scheme restrict
--- input
text: http://d.hatena.ne.jp/
conf:
  accept_schemes: [mailto]
--- expected: http://d.hatena.ne.jp/

=== basic with http_link_string
--- input
text: http://d.hatena.ne.jp/hatenachan/
conf:
  http_link_string: $host$path
--- expected: <a href="http://d.hatena.ne.jp/hatenachan/" rel="nofollow" class="url">d.hatena.ne.jp/hatenachan/</a>

=== tel
--- input
text: 000-0000-0000
conf: ~
--- expected: <a href="tel:00000000000" rel="nofollow" class="url">tel:00000000000</a>

=== tel with scheme
--- input
text: tel:000-0000-0000
conf: ~
--- expected: <a href="tel:00000000000" rel="nofollow" class="url">tel:00000000000</a>

=== mailto
--- input
text: aaa@example.com
conf: ~
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url">mailto:aaa@example.com</a>

=== mailto with scheme
--- input
text: mailto:aaa@example.com
conf: ~
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url">mailto:aaa@example.com</a>

=== pocket hatena
--- input
text: http://d.hatena.ne.jp/
conf:
  pocket_hatena: true
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url">http://d.hatena.ne.jp/</a><a href="http://mgw.hatena.ne.jp/?url=http%3A%2F%2Fd.hatena.ne.jp%2F&noimage=0&split=1" rel="nofollow" class="pocket_hatena">[ph]</a>

=== au_pcsv
--- input
text: http://d.hatena.ne.jp/
conf:
  au_pcsv: true
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url">http://d.hatena.ne.jp/</a><a href="device:pcsiteviewer?url=http://d.hatena.ne.jp/" rel="nofollow" class="au_pcsv">[PCSV]</a>

=== google_gwt
--- input
text: http://d.hatena.ne.jp/
conf:
  google_gwt: true
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url">http://d.hatena.ne.jp/</a><a href="http://www.google.co.jp/gwt/n?u=http%3A%2F%2Fd.hatena.ne.jp%2F&_gwt_noimg=0" rel="nofollow" class="google_gwt">[gwt]</a>

