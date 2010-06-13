package WWW::MobileCarrierJP::DoCoMo::Java;
use WWW::MobileCarrierJP::Declare;
use charnames ':full';
use URI;

my $url = 'http://www.nttdocomo.co.jp/service/imode/make/content/spec/iappli/index.html';

sub scrape {
    my @result;
    my $profile;
    scraper {
        process '//tr[@class="acenter"]', 'models[]', sub {
            my $tree = $_->clone;
            $_->delete for $tree->findnodes('//td[@class="brownLight acenter middle"]');
            $_->delete for $tree->findnodes('//a');

            my $position = 1;
            if (my $new_profile = $tree->findvalue('//td[@rowspan]')) {
                # 余分な文字列削除
                $new_profile =~ s/プロファイル//;
                $profile = $new_profile;
                $position++;
            }

            if ($profile) {
                my %data = ( profile => $profile );
                $data{model} = $tree->findvalue('//td[position()='.$position++.']');
                $data{model} =~ s/\N{GREEK SMALL LETTER MU}/myu/;
                $data{model} =~ s/\（.+）//;
                $data{model} = uc($data{model});

                my $size = $tree->findvalue('//td[position()='.$position++.']');
                $size =~ m/(\d+)(\/(\d+))?/;
                $data{size} = {
                    jar => $1, scratchpad => $3 || 0,
                };

                my $panel  = $tree->findvalue('//td[position()='.$position++.']');
                $panel =~ m/(\d+)\N{MULTIPLICATION SIGN}(\d+)/;
                my ($panel_width, $panel_height) = ($1, $2);

                my $canvas = $tree->findvalue('//td[position()='.$position++.']');
                $canvas =~ m/(\d+)\N{MULTIPLICATION SIGN}(\d+)/;
                my ($canvas_width, $canvas_height) = ($1, $2);

                $data{display} = {
                    panel  => { width => $panel_width,  height => $panel_height  },
                    canvas => { width => $canvas_width, height => $canvas_height },
                };

                my $heap_full = $tree->findvalue('//td[position()='.$position++.']');
                $heap_full =~ m/(\d+)((\N{FULLWIDTH SOLIDUS}|\/)(\d+))?/;
                my ($java, $native) = ($1, $4);
                $data{heap} = {
                    full_appli => { java => $java, native => $native || 0 },
                };

                if ($profile =~ /\Star/) {
                    my $heap_widget = $tree->findvalue('//td[position()='.$position++.']');
                    $data{heap}->{widget} = $heap_widget;
                }

                my $font = $tree->findvalue('//td[position()='.$position++.']');
                $font =~ m/(\d+)\N{MULTIPLICATION SIGN}(\d+)/;
                $data{default_font} = { width => $1, height => $2 };

                push @result, \%data;
            }
        };
    }->scrape(URI->new($url));

    \@result;
};

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::DoCoMo::Java - get iappli informtation from DoCoMo site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::DoCoMo::Java;
    WWW::MobileCarrierJP::DoCoMo::Java->scrape();

=head1 AUTHOR

Seiji Harada < liptontea2k gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>,
L<http://www.nttdocomo.co.jp/english/service/imode/make/content/spec/iappli/index.html>

