use strict;
use warnings;
use App::Mobirc::Plugin::HTMLFilter::CompressHTML;
use Test::Base;

filters {
    input => [qw/compress/],
};

sub compress {
    App::Mobirc::Plugin::HTMLFilter::CompressHTML::_html_filter_compress(undef, shift);
}

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
