package WWW::MobileCarrierJP::EZWeb::Model;
use WWW::MobileCarrierJP::Declare;

parse_one(
    urls => ['http://www.au.kddi.com/ezfactory/tec/spec/new_win/ezkishu.html'],
    xpath => '//tr[@valign="middle" and @bgcolor="#ffffff"]',
    scraper => scraper {
        col 1 => 'model_long', 'TEXT';
        col 2 => 'browser_type', 'TEXT';

        col 3 => 'is_color',
            [ 'TEXT', sub { /モノクロ/ ? undef : 1 } ];
        col 5 => 'display_browsing',
            [ 'TEXT', sub { /^(\d+)×(\d+)$/; +{width => $1, height => $2 } } ];
        col 6 => 'display_wallpaper',
            [ 'TEXT', sub { /^(\d+)×(\d+)$/; +{width => $1, height => $2 } } ];
        col 7 => 'gif',
            [ 'TEXT', sub { /○/ ? 1 : undef } ];
        col 8 => 'jpeg',
            [ 'TEXT', sub { /○/ ? 1 : undef } ];
        col 9 => 'png',
            [ 'TEXT', sub { /○|△/ ? 1 : undef } ];
        col 12 =>'flash_lite',
            [ 'TEXT', sub { /●/ ? '2.0' : (/◎|○/ ? '1.1' : undef) } ];
    },
);

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::EZWeb::Model - get Model informtation from EZWeb site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::EZWeb::Model;
    WWW::MobileCarrierJP::EZWeb::Model->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

