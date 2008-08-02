use strict;
use warnings;
use Test::Base;
use App::Mobirc;

plan tests => 1*blocks;

filters {
    input => ['yaml', 'clickable' ]
};

sub clickable {
    my $x = shift;
    my $global_context = App::Mobirc->new(
        {
            httpd  => { lines => 40 },
            global => { keywords => [qw/foo/] }
        }
    );
    $global_context->load_plugin( { module => 'MessageBodyFilter::Clickable', config => $x->{conf} } );
    my ($res, ) = $global_context->run_hook_filter('message_body_filter', $x->{text});
    $res;
}

run_is input => 'expected';

__END__

=== basic
--- input
text: http://d.hatena.ne.jp/
conf: ~
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a>

=== basic with amp
--- input
text: http://www.google.co.jp/search?hl=ja&q=foo
conf: ~
--- expected: <a href="http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="url" target="_blank">http://www.google.co.jp/search?hl=ja&amp;q=foo</a>

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
--- expected: <a href="http://d.hatena.ne.jp/hatenachan/" rel="nofollow" class="url" target="_blank">d.hatena.ne.jp/hatenachan/</a>

=== tel
--- input
text: 000-0000-0000
conf: ~
--- expected: <a href="tel:00000000000" rel="nofollow" class="url" target="_blank">000-0000-0000</a>

=== tel with scheme
--- input
text: tel:000-0000-0000
conf: ~
--- expected: <a href="tel:00000000000" rel="nofollow" class="url" target="_blank">tel:000-0000-0000</a>

=== mailto
--- input
text: aaa@example.com
conf: ~
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url" target="_blank">aaa@example.com</a>

=== mailto with scheme
--- input
text: mailto:aaa@example.com
conf: ~
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url" target="_blank">mailto:aaa@example.com</a>

=== mailto
--- input
text: <aaa@example.com>
conf: ~
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url" target="_blank">&lt;mailto:aaa@example.com&gt;</a>

=== pocket hatena
--- input
text: http://d.hatena.ne.jp/
conf:
  pocket_hatena: 1
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a><a href="http://mgw.hatena.ne.jp/?url=http%3A%2F%2Fd.hatena.ne.jp%2F;noimage=0;split=1" rel="nofollow" class="pocket_hatena" target="_blank">[ph]</a>

=== au_pcsv
--- input
text: http://d.hatena.ne.jp/
conf:
  au_pcsv: 1
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a><a href="device:pcsiteviewer?url=http://d.hatena.ne.jp/" rel="nofollow" class="au_pcsv" target="_blank">[PCSV]</a>

=== au_pcsv with amp
--- input
text: http://www.google.co.jp/search?hl=ja&q=foo
conf:
  au_pcsv: 1
--- expected: <a href="http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="url" target="_blank">http://www.google.co.jp/search?hl=ja&amp;q=foo</a><a href="device:pcsiteviewer?url=http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="au_pcsv" target="_blank">[PCSV]</a>

=== google_gwt
--- input
text: http://d.hatena.ne.jp/
conf:
  google_gwt: 1
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a><a href="http://www.google.co.jp/gwt/n?u=http%3A%2F%2Fd.hatena.ne.jp%2F;_gwt_noimg=0" rel="nofollow" class="google_gwt" target="_blank">[gwt]</a>

