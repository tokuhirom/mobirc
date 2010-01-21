package Data::Recursive::Encode;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';
use Encode ();
use Carp ();
use Scalar::Util qw(blessed);

sub _apply {
    my $code = shift;

    my @retval;
    for my $arg (@_) {
        my $class = ref $arg;
        my $val =
            !$class ? 
                $code->($arg) :
            blessed($arg) ?
                $arg : # through
            UNIVERSAL::isa($arg, 'ARRAY') ? 
                +[ _apply($code, @$arg) ] :
            UNIVERSAL::isa($arg, 'HASH')  ? 
                +{
                    map { $code->($_) => _apply($code, $arg->{$_}) }
                    keys %$arg
                } :
            UNIVERSAL::isa($arg, 'SCALAR') ? 
                \do{ _apply($code, $$arg) } :
            UNIVERSAL::isa($arg, 'GLOB')  ? 
                $arg : # through
            UNIVERSAL::isa($arg, 'CODE') ? 
                $arg : # through
            Carp::croak("I don't know how to apply to $class");
        push @retval, $val;
    }
    return wantarray ? @retval : $retval[0];
}

sub decode {
    my ($class, $encoding, $stuff, $check) = @_;
    _apply(sub { Encode::decode $encoding, $_[0], $check }, $stuff);
}

sub encode {
    my ($class, $encoding, $stuff, $check) = @_;
    _apply(sub { Encode::encode $encoding, $_[0], $check }, $stuff);
}

sub decode_utf8 {
    my ($class, $stuff, $check) = @_;
    _apply(sub { Encode::decode_utf8($_[0], $check) }, $stuff);
}

sub encode_utf8 {
    my ($class, $stuff) = @_;
    _apply(sub { Encode::encode_utf8($_[0]) }, $stuff);
}

1;
__END__

=encoding utf8

=head1 NAME

Data::Recursive::Encode - Encode/Decode Values In A Structure

=head1 SYNOPSIS

    use Data::Recursive::Encode;

    Data::Recursive::Encode->decode('euc-jp', $data);
    Data::Recursive::Encode->encode('euc-jp', $data);
    Data::Recursive::Encode->decode_utf8($data);
    Data::Recursive::Encode->encode_utf8($data);

=head1 DESCRIPTION

Data::Recursive::Encode visits each node of a structure, and returns a new
structure with each node's encoding (or similar action). If you ever wished
to do a bulk encode/decode of the contents of a structure, then this
module may help you.

=head1 METHODS

=over 4

=item decode

    my $ret = Data::Recursive::Encode->decode($encoding, $data, [CHECK]);

Returns a structure containing nodes which are decoded from the specified
encoding.

=item encode

    my $ret = Data::Recursive::Encode->encode($encoding, $data, [CHECK]);

Returns a structure containing nodes which are encoded to the specified
encoding.

=item decode_utf8

    my $ret = Data::Recursive::Encode->decode_utf8($data, [CHECK]);

Returns a structure containing nodes which have been processed through
decode_utf8.

=item encode_utf8

    my $ret = Data::Recursive::Encode->encode_utf8($data);

Returns a structure containing nodes which have been processed through
encode_utf8.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

This module is inspired from L<Data::Visitor::Encode>, but this module depended to too much modules.
I want to use this module in pure-perl, but L<Data::Visitor::Encode> depend to XS modules.

L<Unicode::RecursiveDowngrade> does not supports perl5's Unicode way correctly.

=head1 LICENSE

Copyright (C) 2010 Tokuhiro Matsuno All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
