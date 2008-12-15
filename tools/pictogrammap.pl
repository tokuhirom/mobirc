use Encode;
use Data::Dumper;
use HTML::Entities::ConvertPictogramMobileJp;
use Encode::JP::Mobile::Charnames;

my $ret = {};
for my $pict qw(
    E6E6
    E6E7
    E6E9
    E6EA
    E6EB
    E6F0
) {
    my $name = Encode::JP::Mobile::Charnames::unicode2name_en(hex $pict);
    $ret->{$name} = {
        'I.sjis' => HTML::Entities::ConvertPictogramMobileJp::_convert_sjis('docomo', $pict),
        'I.uni'  => HTML::Entities::ConvertPictogramMobileJp::_convert_unicode('docomo', $pict),
        'V'      => HTML::Entities::ConvertPictogramMobileJp::_convert_unicode('softbank', $pict),
        'E' => join( '',
            map { HTML::Entities::ConvertPictogramMobileJp::_ezuni2tag($_) }
              map { unpack 'U*', $_ }
              split //,
            decode "x-utf8-kddi",
            encode( "x-utf8-kddi", chr( hex $pict ) ) ),
    };
}

$Data::Dumper::Indent = 1;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Sortkeys = 1;

print Dumper($ret);

# docomo, 
