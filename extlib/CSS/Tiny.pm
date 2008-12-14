package CSS::Tiny;

=pod

=head1 NAME

CSS::Tiny - Read/Write .css files with as little code as possible

=head1 SYNOPSIS

    # In your .css file
    H1 { color: blue }
    H2 { color: red; font-family: Arial }
    .this, .that { color: yellow }
    
    # In your program
    use CSS::Tiny;
    
    # Create a CSS stylesheet
    my $CSS = CSS::Tiny->new();
    
    # Open a CSS stylesheet
    $CSS = CSS::Tiny->read( 'style.css' );
    
    # Reading properties
    my $header_color = $CSS->{H1}->{color};
    my $header2_hashref = $CSS->{H2};
    my $this_color = $CSS->{'.this'}->{color};
    my $that_color = $CSS->{'.that'}->{color};
    
    # Changing styles and properties
    $CSS->{'.newstyle'} = { color => '#FFFFFF' }; # Add a style
    $CSS->{H1}->{color} = 'black';                # Change a property
    delete $CSS->{H2};                            # Delete a style
    
    # Save a CSS stylesheet
    $CSS->write( 'style.css' );
    
    # Get the CSS as a <style>...</style> tag
    $CSS->html;

=head1 DESCRIPTION

C<CSS::Tiny> is a perl class to read and write .css stylesheets with as 
little code as possible, reducing load time and memory overhead. CSS.pm
requires about 2.6 meg or ram to load, which is a large amount of 
overhead if you only want to do trivial things.
Memory usage is normally scoffed at in Perl, but in my opinion should be
at least kept in mind.

This module is primarily for reading and writing simple files, and anything
we write shouldn't need to have documentation/comments. If you need
something with more power, move up to CSS.pm. With the increasing complexity
of CSS, this is becoming more common, but many situations can still live
with simple CSS files.

=head2 CSS Feature Support

C<CSS::Tiny> supports grouped styles of the form
C<this, that { color: blue }> correctly when reading, ungrouping them into
the hash structure. However, it will not restore the grouping should you
write the file back out. In this case, an entry in the original file of
the form

    H1, H2 { color: blue }

would become

    H1 { color: blue }
    H2 { color: blue }

C<CSS::Tiny> handles nested styles of the form C<P EM { color: red }>
in reads and writes correctly, making the property available in the
form

    $CSS->{'P EM'}->{color}

C<CSS::Tiny> ignores comments of the form C</* comment */> on read
correctly, however these comments will not be written back out to the
file.

=head1 CSS FILE SYNTAX

Files are written in a relatively human-orientated form, as follows:

    H1 {
        color: blue;
    }
    .this {
    	color: red;
    	font-size: 10px;
    }
    P EM {
    	color: yellow;
    }

When reading and writing, all property descriptors, for example C<color>
and C<font-size> in the example above, are converted to lower case. As an
example, take the following CSS.

    P {
    	Font-Family: Verdana;
    }

To get the value C<'Verdana'> from the object C<$CSS>, you should
reference the key C<$CSS-E<gt>{P}-E<gt>{font-family}>.

=head1 METHODS

=cut

use strict;
BEGIN {
	require 5.004;
	$CSS::Tiny::VERSION = '1.15';
	$CSS::Tiny::errstr  = '';
}

=pod

=head2 new

The constructor C<new> creates and returns an empty C<CSS::Tiny> object.

=cut

sub new { bless {}, shift }

=pod

=head2 read $filename

The C<read> constructor reads a CSS stylesheet, and returns a new
C<CSS::Tiny> object containing the properties in the file.

Returns the object on success, or C<undef> on error.

=cut

sub read {
	my $class = shift;

	# Check the file
	my $file = shift or return $class->_error( 'You did not specify a file name' );
	return $class->_error( "The file '$file' does not exist" )          unless -e $file;
	return $class->_error( "'$file' is a directory, not a file" )       unless -f _;
	return $class->_error( "Insufficient permissions to read '$file'" ) unless -r _;

	# Read the file
	local $/ = undef;
	open( CSS, $file ) or return $class->_error( "Failed to open file '$file': $!" );
	my $contents = <CSS>;
	close( CSS );

	$class->read_string( $contents )
}

=pod

=head2 read_string $string

The C<read_string> constructor reads a CSS stylesheet from a string.

Returns the object on success, or C<undef> on error.

=cut

sub read_string {
	my $self = bless {}, shift;

	# Flatten whitespace and remove /* comment */ style comments
	my $string = shift;
	$string =~ tr/\n\t/  /;
	$string =~ s!/\*.*?\*\/!!g;

	# Split into styles
	foreach ( grep { /\S/ } split /(?<=\})/, $string ) {
		unless ( /^\s*([^{]+?)\s*\{(.*)\}\s*$/ ) {
			return $self->_error( "Invalid or unexpected style data '$_'" );
		}

		# Split in such a way as to support grouped styles
		my $style = $1;
		$style =~ s/\s{2,}/ /g;
		my @styles = grep { s/\s+/ /g; 1; } grep { /\S/ } split /\s*,\s*/, $style;
		foreach ( @styles ) { $self->{$_} ||= {} }

		# Split into properties
		foreach ( grep { /\S/ } split /\;/, $2 ) {
			unless ( /^\s*([\w._-]+)\s*:\s*(.*?)\s*$/ ) {
				return $self->_error( "Invalid or unexpected property '$_' in style '$style'" );
			}
			foreach ( @styles ) { $self->{$_}->{lc $1} = $2 }
		}
	}

	$self
}

=pod

=head2 clone

The C<clone> method creates an identical copy of an existing C<CSS::Tiny>
object.

=cut

BEGIN { eval "use Clone 'clone';"; eval <<'END_PERL' if $@; }
sub clone {
	my $self = shift;
	my $copy = ref($self)->new;
	foreach my $key ( keys %$self ) {
		my $section = $self->{$key};
		$copy->{$key} = {};
		foreach ( keys %$section ) {
			$copy->{$key}->{$_} = $section->{$_};
		}
	}
	$copy;
}
END_PERL

=pod

=head2 write

The C<write $filename> generates the stylesheet for the properties, and 
writes it to disk. Returns true on success. Returns C<undef> on error.

=cut

sub write {
	my $self = shift;
	my $file = shift or return $self->_error( 'No file name provided' );

	# Write the file
	open( CSS, '>'. $file ) or return $self->_error( "Failed to open file '$file' for writing: $!" );
	print CSS $self->write_string;
	close( CSS );

	1
}

=pod

=head2 write_string

Generates the stylesheet for the object and returns it as a string.

=cut

sub write_string {
	my $self = shift;

	# Iterate over the styles
	# Note: We use 'reverse' in the sort to avoid a special case related
	# to A:hover even though the file ends up backwards and looks funny.
	# See http://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes
	my $contents = '';
	foreach my $style ( reverse sort keys %$self ) {
		$contents .= "$style {\n";
		foreach ( sort keys %{ $self->{$style} } ) {
			$contents .= "\t" . lc($_) . ": $self->{$style}->{$_};\n";
		}
		$contents .= "}\n";
	}

	$contents
}

=pod

=head2 html

The C<html> method generates the CSS, but wrapped in a C<style> HTML tag,
so that it can be dropped directly onto a HTML page.

=cut

sub html {
	my $css = $_[0]->write_string or return '';
	"<style type=\"text/css\">\n<!--\n${css}-->\n</style>";
}

=pod

=head2 xhtml

The C<html> method generates the CSS, but wrapped in a C<style> XHTML tag,
so that it can be dropped directly onto an XHTML page.

=cut

sub xhtml {
	my $css = $_[0]->write_string or return '';
	"<style type=\"text/css\">\n/* <![CDATA[ */\n${css}/* ]]> */\n</style>";
}

=pod

=head2 errstr

When an error occurs, you can retrieve the error message either from the
C<$CSS::Tiny::errstr> variable, or using the C<errstr> method.

=cut

sub errstr { $CSS::Tiny::errstr }
sub _error { $CSS::Tiny::errstr = $_[1]; undef }

1;

=pod

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CSS-Tiny>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 SEE ALSO

L<CSS>, L<http://www.w3.org/TR/REC-CSS1>, L<Config::Tiny>, L<http://ali.as/>

=head1 COPYRIGHT

Copyright 2002 - 2007 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
