package POE::Filter::IRC;

use strict;
use warnings;
use POE::Filter::Stackable;
use POE::Filter::IRCD;
use POE::Filter::IRC::Compat;

our $VERSION = '6.02';

sub new {
    my ($package, %opts) = @_;
    $opts{lc $_} = delete $opts{$_} for keys %opts;
    return POE::Filter::Stackable->new(
        Filters => [ 
            POE::Filter::IRCD->new( DEBUG => $opts{debug} ),
            POE::Filter::IRC::Compat->new( DEBUG => $opts{debug} ),
        ],
    );
}

1;
__END__

=head1 NAME

POE::Filter::IRC -- A POE-based parser for the IRC protocol

=head1 SYNOPSIS

 my $filter = POE::Filter::IRC->new();
 my @events = @{ $filter->get( [ @lines ] ) };

=head1 DESCRIPTION

POE::Filter::IRC takes lines of raw IRC input and turns them into weird little
data structures, suitable for feeding to L<POE::Component::IRC|POE::Component::IRC>.
They look like this:

 { name => 'event name', args => [ some info about the event ] }

This module was long deprecated in L<POE::Component::IRC|POE::Component::IRC>.
It now uses the same mechanism that that uses to parse IRC text.

=head1 CONSTRUCTOR

=head2 C<new>

Returns a new L<POE::Filter::Stackable|POE::Filter::Stackable> object containing
a L<POE::Filter::IRCD|POE::Filter::IRCD> object and a
L<POE::Filter::IRC::Compat|POE::Filter::IRC::Compat> object. This does the same
job that POE::Filter::IRC used to do.

=head1 METHODS

See the documentation for POE::Filter::IRCD and POE::Filter::IRC::Compat.

=head1 AUTHOR

Dennis C<fimmtiu> Taylor

Refactoring by Chris C<BinGOs> Williams <chris@bingosnet.co.uk>

=head1 SEE ALSO

The documentation for L<POE|POE> and L<POE::Component::IRC|POE::Component::IRC>.

L<POE::Filter::Stackable|POE::Filter::Stackable>

L<POE::Filter::IRCD|POE::Filter::IRCD>

L<POE::Filter::IRC::Compat|POE::Filter::IRC::Compat>

=cut
