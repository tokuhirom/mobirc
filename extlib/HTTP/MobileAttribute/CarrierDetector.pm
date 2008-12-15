package HTTP::MobileAttribute::CarrierDetector;
use strict;
use warnings;

# this matching should be robust enough
# detailed analysis is done in subclass's parse()
our $DoCoMoRE = '^DoCoMo\/\d\.\d[ \/]';
our $JPhoneRE = '^(?i:J-PHONE\/\d\.\d)';
our $VodafoneRE = '^Vodafone\/\d\.\d';
our $VodafoneMotRE = '^MOT-';
our $SoftBankRE = '^SoftBank\/\d\.\d';
our $SoftBankCrawlerRE = '^Nokia[^\/]+\/\d\.\d';
our $EZwebRE  = '^(?:KDDI-[A-Z]+\d+[A-Z]? )?UP\.Browser\\/';
our $AirHRE = '^Mozilla\/3\.0\((?:WILLCOM|DDIPOCKET)\;';

sub detect {
    my $user_agent = shift;

    if ( $user_agent =~ /$DoCoMoRE/ ) {
        return 'DoCoMo';
    } elsif ( $user_agent =~ /$JPhoneRE|$VodafoneRE|$VodafoneMotRE|$SoftBankRE|$SoftBankCrawlerRE/) {
        return 'ThirdForce';
    } elsif ( $user_agent =~ /$EZwebRE/ ) {
        return 'EZweb';
    } elsif ( $user_agent =~ /$AirHRE/ ) {
        return 'AirHPhone';
    }
    return 'NonMobile';
}

        
1;
__END__

=encoding UTF-8

=head1 NAME

HTTP::MobileAttribute::CarrierDetector - キャリヤ判別ルーチン

=head1 SYNOPSIS

    use HTTP::MobileAttribute::CarrierDetector;

    HTTP::MobileAttribute::CarrierDetector::detect('DoCoMo/1.0/NM502i'); # => DoCoMo

=head1 DESCRIPTION

User-Agent 文字列からケータイキャリヤを判別するよ。

=head1 METHOD

=over 4

=item detect

    HTTP::MobileAttribute::CarrierDetector::detect('DoCoMo/1.0/NM502i'); # => DoCoMo

キャリヤを判定します。

=back

=head1 AUTHOR

Tokuhiro Matsuno
