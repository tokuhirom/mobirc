use strict;
use warnings;
use Test::Base;
use App::Mobirc;

my $global_context = App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$global_context->load_plugin( 'StickyTime' );

plan tests => 1*blocks;

filters {
    input => [qw/sticky/],
    expected => [qw/eval/],
};

run {
    my $block = shift;
    like $block->input, $block->expected;
};

sub sticky {
    my $html = shift;
    my $c = undef;
    ($c, $html) = $global_context->run_hook_filter('html_filter', $c, $html);
    return $html;
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

