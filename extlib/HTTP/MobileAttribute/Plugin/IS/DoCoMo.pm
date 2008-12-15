package HTTP::MobileAttribute::Plugin::IS::DoCoMo;

use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub is_foma : CarrierMethod('DoCoMo') { $_[1]->version eq '2.0' }

1;
__END__

=for stopwords Yoshiki Kurihara TUKA WAP1 WAP2 FOMA

=head1 NAME

HTTP::MobileAttribute::Plugin::IS::DoCoMo - is_* plugin for HTTP::MobileAttribute

=head1 METHODS

=over 4

=item is_foma

    if ($agent->is_foma) { }

returns whether it's FOMA or not.

=back

=head1 AUTHORS

Yoshiki Kurihara

=head1 SEE ALSO

L<HTTP::MobileAttribute>

