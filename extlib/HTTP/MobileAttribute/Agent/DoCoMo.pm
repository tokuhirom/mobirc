package HTTP::MobileAttribute::Agent::DoCoMo;
use strict;
use warnings;
use HTTP::MobileAttribute::Agent::Base;

__PACKAGE__->mk_accessors(qw/version model status bandwidth serial_number card_id comment name/);

sub parse {
    my ( $self, ) = @_;

    my ( $main, $foma_or_comment ) = split / /, $self->user_agent, 2;

    if ( $foma_or_comment && $foma_or_comment =~ s/^\((.*)\)$/$1/ ) {
        # DoCoMo/1.0/P209is (Google CHTML Proxy/1.0)
        $self->{comment} = $1;
        $self->_parse_main($main);
    }
    elsif ($foma_or_comment) {
        # DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)
        @{$self}{qw(name version)} = split m!/!, $main;
        $self->_parse_foma($foma_or_comment);
    }
    else {
        # DoCoMo/1.0/R692i/c10
        $self->_parse_main($main);
    }

}

sub _parse_main {
    my ( $self, $main ) = @_;
    my ( $name, $version, $model, $selfache, @rest ) = split m!/!, $main;
    $self->{name}    = $name;
    $self->{version} = $version;
    $self->{model}   = $model;
    $self->{model}   = 'SH505i' if $self->{model} eq 'SH505i2';

    if ($selfache) {
        $selfache =~ s/^c// or return $self->no_match;
        $self->{cache_size} = $selfache;
    }

    for (@rest) {
        /^ser(\w{11})$/  and do { $self->{serial_number} = $1;      next };
        /^(T[CDBJ])$/    and do { $self->{status}        = $1;      next };
        /^s(\d+)$/       and do { $self->{bandwidth}     = $1;      next };
        /^W(\d+)H(\d+)$/ and do { $self->{display_bytes} = "$1*$2"; next; };
    }
}

sub _parse_foma {
    my ( $self, $foma ) = @_;

    $foma =~ s/^([^\(]+)// or return $self->no_match;
    $self->{model} = $1;
    $self->{model} = 'SH2101V' if $1 eq 'MST_v_SH2101V';    # Huh?

    $foma =~ /^\(/g or return;
    while ($foma =~ /\G
        (?:
            c(\d+)      | # cache size
            ser(\w{15}) | # serial_number
            icc(\w{20}) | # card_id
            (T[CDBJ])   | # status
            W(\d+)H(\d+)  # display_bytes
        )
        [;\)]/gx)
    {
        $1         and $self->{cache_size}    = $1, next;
        $2         and $self->{serial_number} = $2, next;
        $3         and $self->{card_id}       = $3, next;
        $4         and $self->{status}        = $4, next;
        ($5 && $6) and $self->{display_bytes} = "$5*$6", next;
        $self->no_match;
    }
}

1;

