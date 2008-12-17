package App::Mobirc::Pictogram;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT = qw/pictogram/;

my $PICTMAP = {
    '0' => {
        'E'      => '<img localsrc="325" />',
        'I.sjis' => '&#xF990;',
        'I.uni'  => '&#xE6EB;',
        'V'      => '&#xE225;'
    },
    '5' => {
        'E'      => '<img localsrc="184" />',
        'I.sjis' => '&#xF98B;',
        'I.uni'  => '&#xE6E6;',
        'V'      => '&#xE220;'
    },
    '6' => {
        'E'      => '<img localsrc="185" />',
        'I.sjis' => '&#xF98C;',
        'I.uni'  => '&#xE6E7;',
        'V'      => '&#xE221;'
    },
    '8' => {
        'E'      => '<img localsrc="187" />',
        'I.sjis' => '&#xF98E;',
        'I.uni'  => '&#xE6E9;',
        'V'      => '&#xE223;'
    },
    '9' => {
        'E'      => '<img localsrc="188" />',
        'I.sjis' => '&#xF98F;',
        'I.uni'  => '&#xE6EA;',
        'V'      => '&#xE224;'
    },
    '(^-^)' => {
        'E'      => '<img localsrc="257" />',
        'I.sjis' => '&#xF995;',
        'I.uni'  => '&#xE6F0;',
        'V'      => '&#xE057;'
    }
};

sub pictogram {
    my ($name) = @_;

    my $ma = App::Mobirc::Web::Handler->web_context()->mobile_attribute();

    my $key = do {
        if ($ma->is_docomo) {
            if ($ma->is_foma) {
                'I.uni'
            } else {
                'I.sjis'
            }
        } elsif ($ma->is_ezweb) {
            'E'
        } elsif ($ma->is_softbank) {
            'V'
        } elsif ($ma->is_ezweb) {
            'I.sjis'
        }
    };

    my $e = $PICTMAP->{$name} or die "unknown pictogram '$name'";
    if ($key) {
        $e->{$key};
    } else {
        $name;
    }
}

1;
