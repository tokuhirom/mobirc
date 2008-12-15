package HTTP::MobileAttribute::Plugin::IS::ThirdForce;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub is_type_c   :CarrierMethod('ThirdForce') { $_[1]->type =~ /^C/ }
sub is_type_p   :CarrierMethod('ThirdForce') { $_[1]->type =~ /^P/ }
sub is_type_w   :CarrierMethod('ThirdForce') { $_[1]->type =~ /^W/ }
sub is_type_3gc :CarrierMethod('ThirdForce') { $_[1]->type eq '3GC' }

1;
__END__

=for stopwords Yoshiki Kurihara TUKA WAP1 WAP2 FOMA ThirdForce

=head1 NAME

HTTP::MobileAttribute::Plugin::IS::ThirdForce - is_* plugin for ThirdForce phones.

=head1 METHODS

=over 4

=item is_type_c
=item is_type_p
=item is_type_w
=item is_type_3gc

check the type.

=back

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>

