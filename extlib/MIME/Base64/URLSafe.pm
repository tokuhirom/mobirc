package MIME::Base64::URLSafe;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use MIME::Base64;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(urlsafe_b64encode urlsafe_b64decode);

$VERSION = '0.01';

sub encode ($) {
    my $data = encode_base64($_[0], '');
    $data =~ tr|+/=|\-_|d;
    $data;
}

sub decode ($) {
    my $data = $_[0];
    # +/ should not be handled, so convert them to invalid chars
    # also, remove spaces (\t..\r and SP) so as to calc padding len
    $data =~ tr|\-_\t-\x0d |+/|d;
    my $mod4 = length($data) % 4;
    if ($mod4) {
	$data .= substr('====', $mod4);
    }
    decode_base64($data);
}

*urlsafe_b64encode = \&encode;
*urlsafe_b64decode = \&decode;


1;
__END__

=head1 NAME

MIME::Base64::URLSafe - Perl version of Python's URL-safe base64 codec

=head1 SYNOPSIS

  use MIME::Base64::URLSafe;
  
  $encoded = urlsafe_b64encode('Alladdin: open sesame');
  $decoded = urlsafe_b64decode($encoded);

=head1 DESCRIPTION

This module is a perl version of python's URL-safe base64 encoder / decoder.

When embedding binary data in URL, it is preferable to use base64 encoding.  However, two characters ('+' and '/') used in the standard base64 encoding have special meanings in URLs, often leading to re-encoding with URL-encoding, or worse, interoperability problems.

To overcome the problem, the module provides a variation of base64 codec compatible with python's urlsafe_b64encode / urlsafe_b64decode.

Modification rules from base64:

    use '-' and '_' instead of '+' and '/'
    no line feeds
    no trailing equals (=)

The following functions are provided:

    urlsafe_b64encode($str)
    urlsafe_b64decode($str)

If you prefer not to import these routines to your namespace, you can call them as:

    use MIME::Base64::URLSafe ();
    $encoded = MIME::Base64::URLSafe::encode($decoded);
    $decoded = MIME::Base64::URLSafe::decode($encoded);

=head1 SEE ALSO

L<MIME::Base64>

Fore more discussion on using base64 encoding in URL applications, see: http://en.wikipedia.org/wiki/Base64#URL_Applications

=head1 AUTHOR

Kazuho Oku E<lt>kazuho ___at___ labs.cybozu.co.jpE<gt>

Copyright (C) 2006 Cybozu Labs, Inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
