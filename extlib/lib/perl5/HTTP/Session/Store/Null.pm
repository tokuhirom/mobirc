package HTTP::Session::Store::Null;
use strict;
use warnings;

sub new { bless {}, shift }

sub select { }
sub insert { }
sub update { }
sub delete { }
sub cleanup { Carp::croak "This storage doesn't support cleanup" }

1;
__END__

=head1 NAME

HTTP::Session::Store::Null - dummy module for session store

=head1 SYNOPSIS

    HTTP::Session->new(
        store => HTTP::Session::Store::Null->new(),
        state => ...,
        request => ...,
    );

=head1 DESCRIPTION

dummy module for session store

=head1 CONFIGURATION

nop

=head1 METHODS

=over 4

=item select

=item update

=item delete

=item insert

for internal use only

=back

=head1 SEE ALSO

L<HTTP::Session>

