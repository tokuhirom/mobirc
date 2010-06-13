package HTTP::Session::Store::Test;
use strict;
use warnings;
use base qw/HTTP::Session::Store::OnMemory/;

1;
__END__

=head1 NAME

HTTP::Session::Store::Test - store session data on memory for testing

=head1 SYNOPSIS

    HTTP::Session->new(
        store => HTTP::Session::Store::Test->new(
            data => {
                foo => 'bar',
            }
        ),
        state => ...,
        request => ...,
    );

=head1 DESCRIPTION

store session data on memory for testing

=head1 CONFIGURATION

=over 4

=item data

session data.

=back

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

