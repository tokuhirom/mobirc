package HTTP::Session::Store::OnMemory;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_ro_accessors(qw/data/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # set default values
    $args{data} ||= {};
    bless {%args}, $class;
}

sub select {
    my ( $self, $session_id ) = @_;
    Carp::croak "missing session_id" unless $session_id;
    $self->data->{$session_id};
}

sub insert {
    my ($self, $session_id, $data) = @_;
    Carp::croak "missing session_id" unless $session_id;
    $self->data->{$session_id} = $data;
}

sub update {
    my ($self, $session_id, $data) = @_;
    Carp::croak "missing session_id" unless $session_id;
    $self->data->{$session_id} = $data;
}

sub delete {
    my ($self, $session_id) = @_;
    Carp::croak "missing session_id" unless $session_id;
    delete $self->data->{$session_id};
}

sub cleanup { Carp::croak "This storage doesn't support cleanup" }

1;
__END__

=head1 NAME

HTTP::Session::Store::OnMemory - store session data on memory

=head1 SYNOPSIS

    HTTP::Session->new(
        store => HTTP::Session::Store::OnMemory->new(
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

