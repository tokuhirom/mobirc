package HTTP::Session::State::Null;
use strict;
use HTTP::Session::State::Base;

sub get_session_id  { }
sub response_filter { }

1;
__END__

=head1 NAME

HTTP::Session::State::Null - nop

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::Null->new(),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

this is a dummy session state module =)

=head1 CONFIGURATION

nothing.

=head1 METHODS

=over 4

=item get_session_id

=item response_filter

for internal use only

=back

=head1 SEE ALSO

L<HTTP::Session>

