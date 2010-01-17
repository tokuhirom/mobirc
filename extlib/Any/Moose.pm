package Any::Moose;
our $VERSION = '0.11';
# ABSTRACT: use Moose or Mouse modules

use 5.006_002;
use strict;
use warnings;

use Carp ();

our $PREFERRED = $ENV{'ANY_MOOSE'};

sub import {
    my $self = shift;
    my $pkg  = caller;

    # Any::Moose gives you strict and warnings
    strict->import;
    warnings->import;

    # first options are for Mo*se
    unshift @_, 'Moose' if !@_ || ref($_[0]);

    while (my $module = shift) {
        my $options = @_ && ref($_[0]) ? shift : [];

        $options = $self->_canonicalize_options(
            module  => $module,
            options => $options,
            package => $pkg,
        );

        $self->_install_module($options);
    }

    # give them any_moose too
    no strict 'refs';
    *{$pkg.'::any_moose'} = \&any_moose;
}

sub unimport {
    my $sel = shift;
    my $pkg = caller;
    my $module;

    if(@_){
        $module = any_moose(shift, $pkg);
    }
    else {
        $module = _backer_of($pkg);
    }
    my $e = do{
        local $@;
        eval "package $pkg;\n"
           . '$module->unimport();';
        $@;
   };
   Carp::croak("Cannot unimport Any::Moose: $e") if $e;
   return;
}

sub _backer_of {
    my $pkg = shift;

    if(exists $INC{'Mouse.pm'}){
        my $meta = Mouse::Util::get_metaclass_by_name($pkg);
        if ($meta) {
            return 'Mouse::Role' if $meta->isa('Mouse::Meta::Role');
            return 'Mouse'       if $meta->isa('Mouse::Meta::Class');
       }
    }

    if (_is_moose_loaded()) {
        my $meta = Class::MOP::get_metaclass_by_name($pkg);
        if ($meta) {
            return 'Moose::Role' if $meta->isa('Moose::Meta::Role');
            return 'Moose'       if $meta->isa('Moose::Meta::Class');
        }
    }

    return undef;
}

sub _canonicalize_options {
    my $self = shift;
    my %args = @_;

    my %options;
    if (ref($args{options}) eq 'HASH') {
        %options = %{ $args{options} };
    }
    else {
        %options = (
            imports => $args{options},
        );
    }

    $options{package} = $args{package};
    $options{module}  = any_moose($args{module}, $args{package});

    return \%options;
}

sub _install_module {
    my $self    = shift;
    my $options = shift;

    my $module = $options->{module};
    (my $file = $module . '.pm') =~ s{::}{/}g;

    require $file;

    my $e = do {
        local $@;
        eval "package $options->{package};\n"
           . '$module->import(@{ $options->{imports} });';
        $@;
    };
    Carp::croak("Cannot import Any::Moose: $e") if $e;
    return;
}

sub any_moose {
    my $fragment = _canonicalize_fragment(shift);
    my $package  = shift || caller;

    # Mouse gets first dibs because it doesn't introspect existing classes

    my $backer = _backer_of($package) || '';

    if ($backer =~ /^Mouse/) {
        $fragment =~ s/^Moose/Mouse/;
        return $fragment;
    }

    return $fragment if $backer =~ /^Moose/;

    if (!$PREFERRED) {
        local $@;
        if (_is_moose_loaded()) {
            $PREFERRED = 'Moose';
        }
        elsif (eval { require Mouse }) {
            $PREFERRED = 'Mouse';
        }
        elsif (eval { require Moose }) {
            $PREFERRED = 'Moose';
        }
        else {
            require Carp;
            Carp::confess("Unable to locate Mouse or Moose in INC");
        }
    }

    $fragment =~ s/^Moose/Mouse/ if mouse_is_preferred();
    return $fragment;
}

sub load_class {
    my ($class_name) = @_;
    return Class::MOP::load_class($class_name) if moose_is_preferred();
    return Mouse::load_class($class_name);
}

sub is_class_loaded {
    my ($class_name) = @_;
    return Class::MOP::is_class_loaded($class_name) if moose_is_preferred();
    return Mouse::is_class_loaded($class_name);
}

sub moose_is_preferred { $PREFERRED eq 'Moose' }
sub mouse_is_preferred { $PREFERRED eq 'Mouse' }

sub _is_moose_loaded { exists $INC{'Class/MOP.pm'} }

sub is_moose_loaded {
    Carp::carp("Any::Moose::is_moose_loaded is deprecated. Please use Any::Moose::moose_is_preferred instead");
    goto \&_is_moose_loaded;
}

sub _canonicalize_fragment {
    my $fragment = shift;

    return 'Moose' if !$fragment;

    # any_moose("X::Types") -> any_moose("MooseX::Types")
    $fragment =~ s/^X::/MooseX::/;

    # any_moose("::Util") -> any_moose("Moose::Util")
    $fragment =~ s/^::/Moose::/;

    # any_moose("Mouse::Util") -> any_moose("Moose::Util")
    $fragment =~ s/^Mouse(X?)\b/Moose$1/;

    # any_moose("Util") -> any_moose("Moose::Util")
    $fragment =~ s/^(?!Moose)/Moose::/;

    return $fragment;
}

1;


=pod

=head1 NAME

Any::Moose - use Moose or Mouse modules

=head1 VERSION

version 0.11

=head1 SYNOPSIS

=head2 BASIC

    package Class;

    # uses Moose if it's loaded, Mouse otherwise
    use Any::Moose;

    # cleans the namespace up
    no Any::Moose;

=head2 OTHER MODULES

    package Other::Class;
    use Any::Moose;

    # uses Moose::Util::TypeConstraints if the class has loaded Moose,
    # Mouse::Util::TypeConstraints otherwise.
    use Any::Moose '::Util::TypeConstraints';

=head2 COMPLEX USAGE

    package My::Meta::Class;
    use Any::Moose;

    # uses subtype from Moose::Util::TypeConstraints if the class loaded Moose,
    # subtype from Mouse::Util::TypeConstraints otherwise.
    # similarly for Mo*se::Util's does_role
    use Any::Moose (
        '::Util::TypeConstraints' => ['subtype'],
        '::Util' => ['does_role'],
    );

    # uses MouseX::Types
    use Any::Moose 'X::Types';

    # gives you the right class name depending on which Mo*se was loaded
    extends any_moose('::Meta::Class');

=head1 DESCRIPTION

Actual documentation is forthcoming, once we solidify all the bits of the API.
The examples above are very likely to continue working.

=head1 SEE ALSO

L<Moose>

L<Mouse>

=head1 AUTHORS

  Shawn M Moore <sartak@bestpractical.com>
  Florian Ragwitz <rafl@debian.org>
  Stevan Little <stevan@iinteractive.com>
  Tokuhiro Matsuno <tokuhirom@gmail.com>
  Goro Fuji <gfuji@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Best Practical Solutions.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut


__END__

