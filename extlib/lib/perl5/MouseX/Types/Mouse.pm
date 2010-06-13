package MouseX::Types::Mouse;

use MouseX::Types;
use Mouse::Util::TypeConstraints ();

use constant type_storage => {
    map { $_ => $_ } Mouse::Util::TypeConstraints->list_all_builtin_type_constraints
};

1;
__END__

=head1 NAME

MouseX::Types::Mouse - Types shipped with Mouse

=head1 SYNOPSIS

  package Foo;
  use Mouse;
  use MouseX::Types::Mouse qw( Int ArrayRef );

  has name => (
    is  => 'rw',
    isa => Str;
  );

  has ids => (
    is  => 'rw',
    isa => ArrayRef[Int],
  );

  1;

=head1 SEE ALSO

L<MouseX::Types>

L<Mouse::Util::TypeConstraints>

=cut
