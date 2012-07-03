package JavaScript::Value::Escape;

use strict;
use warnings;
use 5.8.1;
use base qw/Exporter/;

our $VERSION   = '0.06';
our @EXPORT    = qw/javascript_value_escape/;
our @EXPORT_OK = qw/js/;

my %e = (
    q!\\! => 'u005c',
    q!"! => 'u0022',
    q!'! => 'u0027',
    q!<! => 'u003c',
    q!>! => 'u003e',
    q!&! => 'u0026',
    q!=! => 'u003d',
    q!-! => 'u002d',
    q!;! => 'u003b',
    q!+! => 'u002b',
    "\x{2028}" => 'u2028',
    "\x{2029}" => 'u2029',
);
map { $e{pack('U',$_)} = sprintf("u%04d",$_) } (0x00..0x1f,0x7f);

*js = \&javascript_value_escape; # alias

sub javascript_value_escape {
    my $text = shift;
    $text =~ s!([\\"'<>&=\-;\+\x00-\x1f\x7f]|\x{2028}|\x{2029})!\\$e{$1}!g if defined $text;
    return $text;
}

1;
__END__

=head1 NAME

JavaScript::Value::Escape - Avoid XSS with JavaScript value interpolation

=head1 SYNOPSIS

  use JavaScript::Value::Escape;

  my $escaped = javascript_value_escape(q!&foo"bar'</script>!);
  # $escaped is "\u0026foo\u0022bar\u0027\u003c\/script\u003e"

  my $html_escaped = javascript_value_escape(Text::Xslate::Util::escape_html(q!&foo"bar'</script>!));

  print <<EOF;
  <script>
  var param = '$escaped';
  alert(param);

  document.write('$html_escaped');

  </script>
  EOF

=head1 DESCRIPTION

There are a lot of XSS, a security hole typically found in web applications,
caused by incorrect (or lack of) JavaScript escaping. This module is aimed to
provide a secure JavaScript escaping to avoid XSS with JavaScript values.

The escaping routine JavaScript::Value::Escape provides escapes
q!"!, q!'!, q!&!, q!=!, q!-!, q!+!, q!;!, q!<!, q!>!, q!/!, q!\! and
control characters to JavaScript unicode entities like "\u0026".

=head1 EXPORT FUNCTION

=over 4

=item javascript_value_escape($value :Str) :Str

Escape a string. The argument of this function must be a text string
(a.k.a. UTF-8 flagged string, Perl's internal form).

This is exported by default.

=item js($value :Str) :Str

Alias to C<javascript_value_escape()> for convenience.

This is exported by your request.

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 THANKS TO

Fuji, Goro (gfx)

=head1 SEE ALSO

L<http://subtech.g.hatena.ne.jp/mala/20100222/1266843093> - About XSS caused by buggy JavaScript escaping for HTML script sections (Japanese)

L<http://blog.nomadscafe.jp/2010/11/htmlscript.html> - Wrote a module (JavaScript::Value::Escape) to escape data for HTML script sections (Japanese)

L<RFC4627> - The application/json Media Type for JSON

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
