package WWW::MobileCarrierJP::ThirdForce::Java;
use WWW::MobileCarrierJP::Declare;
use charnames ':full';

parse_one(
    urls => ['http://creation.mb.softbank.jp/terminal/?lup=y&cat=sappli'],
    xpath => q(//tr[@bgcolor="#FFFFFF" and @height="18"]),
    scraper => scraper {
        my $limit;
        col 1 => 'model'        => 'TEXT';
        col 2 => 'heap'         => [
            'TEXT', sub {
                /(\d+)(M|K)(\((\d+)(M|K)\))?/; +{ base => _exchange($1, $2), ex => _exchange($4, $5) };
        }];
        col 3 => 'cldc'         => [
            'TEXT', sub { s/\N{MULTIPLICATION SIGN}//; s/\s\z// }
        ];
        col 4 => 'midp'         => [
            'TEXT', sub { s/\N{MULTIPLICATION SIGN}//; s/\s\z// }
        ];
        col 5 => 'profile'      => [ 'TEXT', sub { s/\N{MULTIPLICATION SIGN}//; s/\s\z// } ];
        col 6 => 'felica_api'   => [ 'TEXT', sub { s/\N{MULTIPLICATION SIGN}//; s/\s\z// } ];
        col 7 => 'location_api' => [
            'TEXT', sub {
                s/\N{MULTIPLICATION SIGN}//; &_marubatsu;
        }];
        col 9 => 'limit'        => [
            'TEXT', sub {
                s/\N{MULTIPLICATION SIGN}//; /(\d+)(M|K)/; _exchange($1, $2);
        }];
        col 8 => 'size'         => [
            'TEXT', sub {
                /(\d+)(M|K)\/(\d+)(M|K)\/(\d+)(M|K)/;
                +{ jad => _exchange($1, $2), jar => _exchange($3, $4), rs => _exchange($5, $6) };
        }];
    },
);

sub _marubatsu { $_ =~ /\N{WHITE CIRCLE}|\N{BULLSEYE}/ ? 1 : 0 }

sub _exchange {
    my ($heap, $sufix) = @_;
    return 0 if !$heap || !$sufix;
    return $heap * 1024 if $sufix eq 'K';
    return $heap * 1024 * 1024 if $sufix eq 'M';
    return 0;
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::ThirdForce::Java - get Java informtation from ThirdForce site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::ThirdForce::Java;
    WWW::MobileCarrierJP::ThirdForce::Java->scrape();

=head1 AUTHOR

Seiji Harada < liptontea2k gmail com >

=head1 SEE ALSO

L<WWW::MobileCarrierJP>

