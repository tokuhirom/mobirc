package WWW::MobileCarrierJP;
use strict;
use warnings;

our $VERSION = '0.44';

1;

__END__

=head1 NAME

WWW::MobileCarrierJP - scrape mobile carrier information

=head1 WARNINGS

THIS SOFTWARE IS STILL UNDER ALPHA STATUS.DON'T USE ME :)

=head1 DESCRIPTION

Japanese Mobile Phone Carrier doesn't feed any information by the machine readable format :(

This is good wrapper for this problem.

This module makes machine readable format from html :)

=head1 TODO

 - softbank flash info

=head1 KNOWLEDGE

=head2 IMAGE

=head3 ThirdForce

softbank phone supports jpeg(without type C2).

softbank phone supports gif(without type C, P, W).

L<http://www2.developers.softbankmobile.co.jp/dp/tool_dl/download.php?docid=120&companyid=>

=head1 AUTHOR

Tokuhiro Matsuno <tokuhirom gmail com>

=head1 THANKS TO

nobjas
kazeburo
takefumi
masahiro chiba

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.
