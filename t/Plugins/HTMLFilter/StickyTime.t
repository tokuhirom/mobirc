use strict;
use warnings;
use App::Mobirc::Plugin::HTMLFilter::StickyTime;
use Test::Base;

plan tests => 1*blocks;

filters {
    input => [qw/compress/],
    expected => [qw/eval/],
};

run {
    my $block = shift;
    like $block->input, $block->expected;
};

sub compress {
    App::Mobirc::Plugin::HTMLFilter::StickyTime::_html_filter(undef, shift);
}

__END__

===
--- input
<h1>foo</h1>
<!-- comment -->
<div class="bar">
    yeah
    <a href="/foo">foo</a>
</div>
--- expected
qr{<a href="/foo\?t=\d+">foo</a>}

