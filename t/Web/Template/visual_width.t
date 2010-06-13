use strict;
use warnings;
use utf8;
use Test::Requires 'Text::VisualWidth::UTF8';
use Test::More tests => 22;
use App::Mobirc::Web::Template;
use Encode;

is App::Mobirc::Web::Template::visual_width("あいうえお123"), Text::VisualWidth::UTF8::width('あいうえお123');
for my $i (0..20) {
    is App::Mobirc::Web::Template::visual_trim("あいうえお123ＡＢＣ", $i), decode_utf8(Text::VisualWidth::UTF8::trim('あいうえお123ＡＢＣ', $i));
}

