use t::Utils;
use Test::Base;
use App::Mobirc;

plan tests => 1*blocks;

filters {
    input => ['yaml', 'clickable' ]
};

sub clickable {
    my $x = shift;
    create_global_context(); # create fresh context :)

    global_context->load_plugin( { module => 'MessageBodyFilter::Clickable', config => $x->{conf} } );
    my ($res, ) = global_context->run_hook_filter('message_body_filter', $x->{text});
    $res;
}

run_is input => 'expected';

__END__

=== basic
--- input
text: http://d.hatena.ne.jp/
conf:
  pocket_hatena: 0
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a>

=== basic with amp
--- input
text: http://www.google.co.jp/search?hl=ja&q=foo
conf:
  pocket_hatena: 0
--- expected: <a href="http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="url" target="_blank">http://www.google.co.jp/search?hl=ja&amp;q=foo</a>

=== basic scheme restrict
--- input
text: http://d.hatena.ne.jp/
conf:
  pocket_hatena: 0
  accept_schemes: [mailto]
--- expected: http://d.hatena.ne.jp/

=== basic with http_link_string
--- input
text: http://d.hatena.ne.jp/hatenachan/
conf:
  pocket_hatena: 0
  http_link_string: $host$path
--- expected: <a href="http://d.hatena.ne.jp/hatenachan/" rel="nofollow" class="url" target="_blank">d.hatena.ne.jp/hatenachan/</a>

=== tel
--- input
text: 000-0000-0000
conf:
  pocket_hatena: 0
--- expected: <a href="tel:00000000000" rel="nofollow" class="url" target="_blank">000-0000-0000</a>

=== tel with scheme
--- input
text: tel:000-0000-0000
conf:
  pocket_hatena: 0
--- expected: <a href="tel:00000000000" rel="nofollow" class="url" target="_blank">tel:000-0000-0000</a>

=== mailto
--- input
text: aaa@example.com
conf:
  pocket_hatena: 0
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url" target="_blank">aaa@example.com</a>

=== mailto with scheme
--- input
text: mailto:aaa@example.com
conf:
  pocket_hatena: 0
--- expected: <a href="mailto:aaa@example.com" rel="nofollow" class="url" target="_blank">mailto:aaa@example.com</a>

=== mailto
--- input
text: <aaa@example.com>
conf:
  pocket_hatena: 0
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
  pocket_hatena: 0
  au_pcsv: 1
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a><a href="device:pcsiteviewer?url=http://d.hatena.ne.jp/" rel="nofollow" class="au_pcsv" target="_blank">[PCSV]</a>

=== au_pcsv with amp
--- input
text: http://www.google.co.jp/search?hl=ja&q=foo
conf:
  pocket_hatena: 0
  au_pcsv: 1
--- expected: <a href="http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="url" target="_blank">http://www.google.co.jp/search?hl=ja&amp;q=foo</a><a href="device:pcsiteviewer?url=http://www.google.co.jp/search?hl=ja&amp;q=foo" rel="nofollow" class="au_pcsv" target="_blank">[PCSV]</a>

=== google_gwt
--- input
text: http://d.hatena.ne.jp/
conf:
  pocket_hatena: 0
  google_gwt: 1
--- expected: <a href="http://d.hatena.ne.jp/" rel="nofollow" class="url" target="_blank">http://d.hatena.ne.jp/</a><a href="http://www.google.co.jp/gwt/n?u=http%3A%2F%2Fd.hatena.ne.jp%2F;_gwt_noimg=0" rel="nofollow" class="google_gwt" target="_blank">[gwt]</a>

=== basic with http_link_target
--- input
text: http://d.hatena.ne.jp/hatenachan/
conf:
  pocket_hatena: 0
  http_link_target: _top
--- expected: <a href="http://d.hatena.ne.jp/hatenachan/" rel="nofollow" class="url" target="_top">http://d.hatena.ne.jp/hatenachan/</a>


=== extract map
--- input
text: http://maps.google.co.jp/maps?q=34.97715353965759,+135.7739943265915+(%E6%9D%B1%E7%A6%8F%E5%AF%BA)&iwloc=A&hl=ja
conf:
  pocket_hatena: 0
  http_extract_map: 1
  http_google_maps_api_key: XXXX
--- expected: <a href="http://maps.google.co.jp/maps?q=34.97715353965759,+135.7739943265915+(%E6%9D%B1%E7%A6%8F%E5%AF%BA)&amp;iwloc=A&amp;hl=ja"><img src="http://maps.google.com/staticmap?markers=34.97715353965759,135.7739943265915&amp;key=XXXX&amp;zoom=13&amp;maptype=mobile&amp;size=140x140&amp;sensor=false"/></a>

