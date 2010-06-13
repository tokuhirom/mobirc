package WWW::MobileCarrierJP::EZWeb::PictogramInfo;
use strict;
use warnings;
use CAM::PDF;
use LWP::UserAgent;
use Carp;
use Encode;

my $url = 'http://www.au.kddi.com/ezfactory/tec/spec/pdf/typeD.pdf';

sub scrape {
    my $ua = LWP::UserAgent->new(agent => __PACKAGE__);
    my $res = $ua->get($url);
    if ($res->is_success) {
        return _process_pdf($res->content);
    } else {
        croak "Can't fetch $url";
    }
}

sub _process_pdf {
    my $content = shift;
    my $doc  = CAM::PDF->new($content);

    my @res;
    foreach my $p (1..$doc->numPages()) {
        my $text = decode("shift_jis", $doc->getPageText($p));
        while ($text =~ m/(\d+)(?: |[abcdef \x{FF43}\x{3000}]+|\x{306A}\x{3057} )([^ ]*) ([0-9A-F]{4})([0-9A-F]{4})([0-9A-F]{4})([0-9A-F]{4})/gs) {
            my %data;
            @data{qw( number name sjis unicode email_jis email_sjis )} = ($1, $2, $3, $4, $5, $6);
            $data{name} =~ s/\n//g;
            push @res, \%data;
        }
    }

    @res = sort { $a->{number} <=> $b->{number} } @res;
    return \@res;
}

1;
__END__

=head1 NAME

WWW::MobileCarrierJP::EZWeb::PictogramInfo - get PictogramInfo informtation from EZWeb site.

=head1 SYNOPSIS

    use WWW::MobileCarrierJP::EZWeb::PictogramInfo;
    WWW::MobileCarrierJP::EZWeb::PictogramInfo->scrape();

=head1 AUTHOR

Tokuhiro Matsuno < tokuhirom gmail com >

=head1 THANKS

This code is copied from Encode-JP-Mobile.

miyagawa++


=head1 SEE ALSO

L<WWW::MobileCarrierJP>

