use t::Utils;
use App::Mobirc::Plugin::HTMLFilter::CompressHTML;
use Test::Base::Less;
use App::Mobirc;

global_context->load_plugin( 'HTMLFilter::CompressHTML' );

for my $block (blocks) {
    test_he_filter {
        my $req = shift;
        my $html = $block->input;
        ($req, $html) = global_context->run_hook_filter('html_filter', $req, $html);
        is($html, $block->expected);
    };
}
done_testing;

__END__

===
--- input
<h1>foo</h1>
<!-- comment -->
<div class="bar">
    yeah
</div>
--- expected
<h1>foo</h1>
<div class="bar">
yeah
</div>
