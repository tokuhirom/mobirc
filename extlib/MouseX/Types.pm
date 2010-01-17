package MouseX::Types;
use 5.006_002;
use Mouse::Exporter; # turns on strict and warnings

our $VERSION = '0.04';

use Mouse::Util::TypeConstraints ();

sub import {
    my($class, %args) = @_;

    my $type_class = caller;

    {
        no strict 'refs';
        *{$type_class . '::import'} = \&_initialize_import;
        push @{$type_class . '::ISA'}, 'MouseX::Types::Base';
    }

    if(my $declare = $args{-declare}){
        if(ref($declare) ne 'ARRAY'){
            Carp::croak("You must pass an ARRAY reference to -declare");
        }
        my $storage = $type_class->type_storage();
        for my $name (@{ $declare }) {
            my $fq_name = $storage->{$name} = $type_class . '::' . $name;

            my $type = sub {
                my $obj = Mouse::Util::TypeConstraints::find_type_constraint($fq_name);
                if($obj){
                    my $type = $type_class->_generate_type($obj);

                    no strict 'refs';
                    no warnings 'redefine';
                    *{$fq_name} = $type;

                    return &{$type};
                 }
                 return $fq_name;
            };

            no strict;
            *{$fq_name} = $type;
        }
    }

    Mouse::Util::TypeConstraints->import({ into => $type_class });
}

sub _initialize_import {
    my $type_class = $_[0];

    my $storage = $type_class->type_storage;

    my @exporting;

    for my $name ($type_class->type_names) {
        my $fq_name = $storage->{$name}
            || Carp::croak(qq{"$name" is not exported by $type_class});

        my $obj = Mouse::Util::TypeConstraints::find_type_constraint($fq_name)
            || Carp::croak(qq{"$name" is declared but not defined in $type_class});

        push @exporting, $name, 'is_' . $name;

        no strict 'refs';
        no warnings 'redefine';
        *{$type_class . '::'    . $name} = $type_class->_generate_type($obj);
        *{$type_class . '::is_' . $name} = $obj->_compiled_type_constraint;
    }

    my($import, $unimport) = Mouse::Exporter->build_import_methods(
        exporting_package => $type_class,
        as_is             => \@exporting,
        groups            => { default => [] },
    );

    no warnings 'redefine';
    no strict 'refs';
    *{$type_class . '::import'}   = $import;   # redefine myself!
    *{$type_class . '::unimport'} = $unimport;

    goto &{$import};
}


{
    package MouseX::Types::Base;
    my %storage;
    sub type_storage { # can be overriden
        return $storage{$_[0]} ||= +{}
    }

    sub type_names {
        my($class) = @_;
        return keys %{$class->type_storage};
    }

    sub _generate_type {
        my($type_class, $type_constraint) = @_;
        return sub {
            if(@_){ # parameterization
                my $param = shift;
                if(!(ref($param) eq 'ARRAY' && @{$param} == 1)){
                    Carp::croak("Syntax error using type $type_constraint (you must pass an ARRAY reference of a parameter type)");
                }
                if(wantarray){
                    return( $type_constraint->parameterize(@{$param}), @_ );
                }
                else{
                    if(@_){
                        Carp::croak("Too many arguments for $type_constraint");
                    }
                    return $type_constraint->parameterize(@{$param});
                }
            }
            else{
                return $type_constraint;
            }
        };
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

MouseX::Types - Organize your Mouse types in libraries

=head1 SYNOPSIS

=head2 Library Definition

  package MyLibrary;

  # predeclare our own types
  use MouseX::Types 
    -declare => [qw(
        PositiveInt NegativeInt
    )];

  # import builtin types
  use MouseX::Types::Mouse 'Int';

  # type definition.
  subtype PositiveInt, 
      as Int, 
      where { $_ > 0 },
      message { "Int is not larger than 0" };
  
  subtype NegativeInt,
      as Int,
      where { $_ < 0 },
      message { "Int is not smaller than 0" };

  # type coercion
  coerce PositiveInt,
      from Int,
          via { 1 };

  1;

=head2 Usage

  package Foo;
  use Mouse;
  use MyLibrary qw( PositiveInt NegativeInt );

  # use the exported constants as type names
  has 'bar',
      isa    => PositiveInt,
      is     => 'rw';
  has 'baz',
      isa    => NegativeInt,
      is     => 'rw';

  sub quux {
      my ($self, $value);

      # test the value
      print "positive\n" if is_PositiveInt($value);
      print "negative\n" if is_NegativeInt($value);

      # coerce the value, NegativeInt doesn't have a coercion
      # helper, since it didn't define any coercions.
      $value = to_PositiveInt($value) or die "Cannot coerce";
  }

  1;

=head1 AUTHORS

Kazuhiro Osawa E<lt>yappo <at> shibuya <döt> plE<gt>

Shawn M Moore

tokuhirom

Goro Fuji

with plenty of code borrowed from L<MooseX::Types>

=head1 REPOSITORY

  git clone git://github.com/yappo/p5-mousex-types.git MouseX-Types

=head1 SEE ALSO

L<Mouse>

L<MooseX::Types>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008-2009, Kazuhiro Osawa and partly based on MooseX::Types, which
is (c) Robert Sedlacek.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
