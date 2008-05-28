use strict;
use warnings;
use App::Mobirc::Plugin::HTMLFilter::ConvertPictograms;
use HTTP::MobileAgent;
use Test::Base;

{
    package DummyContext;
    sub new {
        my ($class, $agent) = @_;
        bless { agent => $agent }, $class;
    }
    sub req {
        my $self = shift;
        bless { %$self }, 'DummyContext';
    }
    sub mobile_agent { shift->{agent} }
}

filters {
    input => [qw/yaml convert/],
};

sub convert {
    my $x = shift;
    my $agent = HTTP::MobileAgent->new($x->{ua});
    App::Mobirc::Plugin::HTMLFilter::ConvertPictograms::_html_convert_pictograms(
        DummyContext->new($agent), $x->{src} );
}

__END__

===
--- input
ua: Vodafone/1.0/V904SH/SHJ001/SN123456789012 Browser/VF-NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1
src: "&#xE63E;&#xE65C;"
--- expected: &#xE04A;&#xE434;

===
--- input
ua: KDDI-SA31 UP.Browser/6.2.0.7.3.129 (GUI) MMP/2.0
src: "&#xE63E;&#xE65C;"
--- expected: <img localsrc="44" /><img localsrc="341" />

