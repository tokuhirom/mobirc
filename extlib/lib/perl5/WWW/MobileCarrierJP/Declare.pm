package WWW::MobileCarrierJP::Declare;
use strict;
use warnings;
use utf8;
use base qw/Exporter/;
use Web::Scraper;
use URI;
use LWP::UserAgent 5.827;
use Carp ();
use Encode qw/decode/;
BEGIN {
    eval q{
        use HTML::TreeBuilder::LibXML 0.04;
        HTML::TreeBuilder::LibXML->replace_original(); # should be void context
        1;
    };
}

our @EXPORT = qw(parse_one scraper process col as_tree result p debug get);

sub p {
    require Data::Dumper;
    print STDERR Data::Dumper::Dumper(@_);
}

sub debug {
    print "$_[0]\n" if $ENV{WMCJP_DEBUG};
}

sub get {
    my $url = shift;
    my $ua = LWP::UserAgent->new(agent => __PACKAGE__);
    my $res = $ua->get($url);
    if ($res->is_success) {
        return decode($res->content_charset, $res->content);
    } else {
        Carp::croak($res->status_line);
    }
}

sub import {
    my $class = shift;

    strict->import;
    warnings->import;
    utf8->import;

    $class->export_to_level(1);
}

sub col {
    my ($n, @args) = @_;
    process "td:nth-child($n)", @args;
}

sub parse_one {
    my %args = @_;

    my $pkg = caller(0);
    no strict 'refs';

    *{"$pkg\::scrape"} = sub {
        my @res = ();
        my $urls = $args{urls} or die "missing urls";
        for my $url ( @$urls ) {
            my $content = get($url);
            if ($args{content_filter}) {
                $content = $args{content_filter}->($content);
            }
            my $result = scraper {
                process $args{xpath}, 'rows[]', $args{scraper};
            }->scrape( $content )->{rows};
            my @result = grep { $_ } @$result;

            push @res, @result;
        }
        return \@res;
    };
}

sub as_tree {
    my $old = shift;

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($old->as_HTML);
    $tree;
}


1;
