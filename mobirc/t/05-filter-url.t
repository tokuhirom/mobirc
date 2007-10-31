use strict;
use warnings;
use Test::Base;
use Mobirc::HTTPD::Filter::URL;

plan tests => 1*blocks;

filters {
    input => ['yaml', 'clickable' ]
};

sub clickable {
    my $x = shift;
    Mobirc::HTTPD::Filter::URL->process( $x->{text}, $x->{conf} );
}

run_is input => 'expected';

__END__

=== basic
--- input
text: http://d.hatena.ne.jp/
conf: ~
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url">http://d.hatena.ne.jp/</a>

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

