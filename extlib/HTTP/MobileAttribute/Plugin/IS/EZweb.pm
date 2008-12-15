package HTTP::MobileAttribute::Plugin::IS::EZweb;

use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub is_win : CarrierMethod('EZweb') { substr($_[1]->device_id, 2, 1) eq '3' }
sub is_tuka : CarrierMethod('EZweb') {
    my ($self, $c) = @_;
    my $tuka = substr($_[1]->device_id, 2, 1);
    if ($c->is_wap2 && $tuka eq 'U') {
        return 1;
    }
    elsif ($tuka eq 'T') {
        return 1;
    }
}
sub is_wap1 : CarrierMethod('EZweb') { !$_[1]->xhtml_compliant }
sub is_wap2 : CarrierMethod('EZweb') { $_[1]->xhtml_compliant }

1;
__END__

=for stopwords Yoshiki Kurihara TUKA WAP1 WAP2

=head1 NAME

HTTP::MobileAttribute::Plugin::IS::DoCoMo - is_* plugin for HTTP::MobileAttribute

=head1 METHODS

=over 4

=item is_win

returns if the agent is win model

=item is_tuka

returns if the agent is TUKA model.

=item is_wap1

returns if the agent is WAP1

=item is_wap2

returns if the agent is WAP2

=back

=head1 AUTHORS

Yoshiki Kurihara

=head1 SEE ALSO

L<HTTP::MobileAttribute>

