package HTTP::MobileAgent::Display;
use strict;
__PACKAGE__->HTTP::MobileAgent::make_accessors(
    qw(width height color depth width_bytes height_bytes)
);

use vars qw($VERSION);
$VERSION = 0.17;

sub new {
    my($class, %data) = @_;
    bless {%data}, $class;
}

sub size {
    my $self = shift;
    return wantarray ? ($self->width, $self->height) : $self->width * $self->height;
}

1;
__END__

=head1 NAME

HTTP::MobileAgent::Display - Display information for HTTP::MobileAgent

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  my $agent   = HTTP::MobileAgent->new;
  my $display = $agent->display;

  my $width  = $display->width;
  my $height = $display->height:
  my($width, $height) = $display->size;

  if ($display->color) {
      my $depth = $display->depth;
  }

  # only available in DoCoMo 505i
  my $width_bytes  = $display->width_bytes;
  my $height_bytes = $display->height_bytes;

=head1 DESCRIPTION

HTTP::MobileAgent::Display is a class for display information on
HTTP::MobileAgent. Handy for image resizing or dispatching.

=head1 METHODS

=over 4

=item width, height

  $width  = $display->width;
  $height = $display->height:

returns width and height of the display.

=item size

  ($width, $height) = $display->size;
  $size = $display->size;

returns width with height in array context, width * height in scalar context.

=item color

  if ($display->color) { }

returns true if it has color capability.

=item depth

  $depth = $display->depth;

returns color depth of the display.

=head1 USING EXTERNAL MAP FILE

If the environment variable DOCOMO_MAP exists, the specified XML data will be used for $DisplayMap.

ex) Please add the following code.

  $ENV{DOCOMO_MAP} = '/path/to/DoCoMoMap.xml';

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::MobileAgent>, L<t/DoCoMoMap.xml>

=cut
