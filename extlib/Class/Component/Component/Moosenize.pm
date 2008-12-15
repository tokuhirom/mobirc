package Class::Component::Component::Moosenize;
use strict;
use warnings;

sub import {
    my($class, %args) = @_;
    $class->NEXT( import => %args );

    my $role_pkg   = "$class\::Role";
    # instasll import method to Plugin base class
    no strict 'refs';
    *{"$role_pkg\::import"} = \&{"Class::Component::Component::Moosenize::Implement::inject_import"};
    unshift @{"$role_pkg\::ISA"}, 'Class::Component::Component::Moosenize::Role';

    my $plugin_pkg = "$class\::Plugin";
    # install register method or wrapping to Plugin base class
    Class::Component::Component::Moosenize::Implement::install_register_method($plugin_pkg);
}

package # hide pause
    Class::Component::Component::Moosenize::Implement;

use strict;
use warnings;

use Carp::Clan qw/Class::Component/;
use Class::Inspector;
use UNIVERSAL::require;

my $METADATA         = {};
sub INSTALL_DEFAULT_METADATA {
    +{
        '%requires'                => {},
        '@requires_with'           => [],
        '$moosenized'              => 0,
        '%method_modifier_role'    => {},
        '%method_modifier_applied' => {},
  };
}

sub install_moose_methods {
    my $pkg = shift;
    $METADATA->{$pkg} ||= INSTALL_DEFAULT_METADATA;

    for my $method (qw/ requires requires_with_attributes with before after around /) {
        no strict 'refs';
        *{"$pkg\::$method"} = sub { unshift @_, $pkg; goto &$method };
    }
}

sub install_register_method {
    my $pkg = shift;
    $pkg->require or die $@;
    $METADATA->{$pkg} ||= INSTALL_DEFAULT_METADATA;

    my $inject_register = \&inject_register;
    no strict 'refs';
    if (${"$pkg\::"}{register}) {
        my $code = \&{"$pkg\::register"};
        no warnings 'redefine';
        *{"$pkg\::register"} = sub {
            $code->(@_);
            goto &inject_register;
        };
    } else {
        my $code = "package $pkg;
            *register = sub {
                my \$class = shift;
                \$class->SUPER::register(\@_);
                unshift \@_, \$class;
                goto \$inject_register;
            };
        ";
        eval $code;## no critic
    }
}

# MyApp::Role->import
sub inject_import {
    my $class  = shift;
    my $caller = caller;

    # instasll Moose like methods to caller class
    install_moose_methods($caller);
    $class->import_after($caller, @_);
}

# MyApp::Plugin->register
sub inject_register {
    my $self   = shift;
    my $caller = ref $self || $self;
    return unless $METADATA->{$caller};
    return if $METADATA->{$caller}->{'$moosenized'}++;
    check_requires($self, $caller, @_);
}

sub check_requires {
    my($self, $caller, $c) = @_;

    my @error;
    for my $class (reverse(@{ Class::Component::Implement->isa_list_cache($caller, $caller) }), $caller) {
        next unless exists $METADATA->{$class};# Moosenize class only

        my %class_requires; # not role class requires
        if (scalar(keys %{ $METADATA->{$class}->{'%requires'} }) && $caller ne $class) {
            %class_requires = %{ $METADATA->{$class}->{'%requires'} };
        } else {
            next unless @{ $METADATA->{$class}->{'@requires_with'} };
        }
        
        for my $role (@{ $METADATA->{$class}->{'@requires_with'} }) {
            while (my($method, $attr) = each %{ $METADATA->{$role}->{'%requires'} }) {
                if (my $msg = _check_requires($self, $c, $role, $caller, $method, $attr)) {
                    push @error, $msg;
                }
            }
        }

        while (my($method, $attr) = each %class_requires) {
            if (my $msg = _check_requires($self, $c, $class, $caller, $method, $attr)) {
                push @error, $msg;
            }
        }
    }
    @error and croak join("\n", @error);
}
sub _check_requires {
    my($self, $c, $caller, $role, $method, $attr) = @_;

    my $code = $self->can($method);
    unless ($code) {
        return sprintf("'%s' requires the method '%s' to be implemented by '%s'", $role, $method, $caller);
    }
    return unless $attr;

    # set attribute
    my $attributes;
    if (ref $attr eq 'HASH') {
        $attributes = [ $attr ]
    } elsif (ref $attr eq 'ARRAY') {
        $attributes = $attr;
    } else {
        croak 'unimplimented refarence type';
    }

    # fetch attribute class, value and go
    for my $data (@{ $attributes }) {
        my($attribute, $value);
        if (ref $data eq 'HASH') {
            ($attribute, $value) = each %{ $data };
        } else {
            $attribute = $data;
        }

	my $attr_class;
        if (($attr_class = $attribute) =~ s/^\+//) {
            $attr_class->require or croak $@;
        } else {
            $attr_class = Class::Component::Implement->pkg_require($c => "Attribute::$attribute");
        }

        $attr_class->register($self, $c, $method, $value, $code);
    }

    return;
}

#
# moose like methods
#
sub requires {
    my $caller = shift;
    my %methods = (@_ == 1) ? ( $_[0] => undef ) : 
                            ref $_[1] ? @_ :
                                      map { $_ => undef } @_;
    my $kaller = ref $caller || $caller;
    return unless $METADATA->{$kaller};
    while (my($key, $value) = each %methods) {
       $METADATA->{$kaller}->{'%requires'}->{$key} = $value;
    }
}
sub requires_with_attributes {
    my $caller     = shift;
    my $attributes = shift;
    requires($caller => map { $_ => $attributes } @_ );
}

sub with {
    my $caller = shift;
    my $role   = shift;
    return unless $METADATA->{$caller};

    $role->require or croak $@;
    my %has_methods = map { $_ => 1 } @{ Class::Inspector->functions($caller) };
    for my $method (@{ Class::Inspector->functions($role) }) {
        next if $has_methods{$method};
        no strict 'refs';
        *{"$caller\::$method"} = *{"$role\::$method"};
    }
    push @{ $METADATA->{$caller}->{'@requires_with'} }, $role;

    apply_method_modifier($caller, $role);
}

sub before {
    my $caller = shift;
    my $code   = pop;
    add_method_modifier($caller, 'before', $_, $code) for @_;
}

sub after {
    my $caller = shift;
    my $code   = pop;
    add_method_modifier($caller, 'after', $_, $code) for @_;
}

sub around {
    my $caller = shift;
    my $code   = pop;
    add_method_modifier($caller, 'around', $_, $code) for @_;
}


#
# method modifier
#
sub apply_method_modifier {
    my($caller, $role) = @_;
    return unless $METADATA->{$role};

    # collect method modifier
    my $apply_methods = {};
    while (my($method, $methods) = each %{ $METADATA->{$role}->{'%method_modifier_role'} }) {
        while (my($type, $codelist) = each %{ $methods }) {
            $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}          ||= {};
            $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}->{$type} ||= [];
            push @{ $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}->{$type} }, @{ $codelist };
        }
        method_modifier($caller, $method);
    }

}

sub add_method_modifier {
    my($caller, $type, $method, $code) = @_;
    return unless $METADATA->{$caller};

    if ($caller->isa('Class::Component::Component::Moosenize::Role')) {
        $METADATA->{$caller}->{'%method_modifier_role'}->{$method}          ||= {};
        $METADATA->{$caller}->{'%method_modifier_role'}->{$method}->{$type} ||= [];
        push @{ $METADATA->{$caller}->{'%method_modifier_role'}->{$method}->{$type} }, $code;
    } else {
        $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}          ||= {};
        $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}->{$type} ||= [];
        push @{ $METADATA->{$caller}->{'%method_modifier_applied'}->{$method}->{$type} }, $code;

        method_modifier($caller, $method);
    }
}


# copied from Class::MOP::Method::Wrapped
my $_build_wrapped_method = sub {
    my $modifier_table = shift;
    my ($before, $after, $around) = (
        $modifier_table->{before},
        $modifier_table->{after},
        $modifier_table->{around},
    );
    if (@$before && @$after) {
        $modifier_table->{cache} = sub {
            $_->(@_) for reverse @{$before};
            my @rval;
            ((defined wantarray) ?
                ((wantarray) ?
                    (@rval = $modifier_table->{around_cache}->(@_))
		 :
                    ($rval[0] = $modifier_table->{around_cache}->(@_)))
	     :
                $modifier_table->{around_cache}->(@_));
            $_->(@_) for @{$after};
            return unless defined wantarray;
            return wantarray ? @rval : $rval[0];
        }
    }
    elsif (@$before && !@$after) {
        $modifier_table->{cache} = sub {
            $_->(@_) for reverse @{$before};
            return $modifier_table->{around_cache}->(@_);
        }
    }
    elsif (@$after && !@$before) {
        $modifier_table->{cache} = sub {
            my @rval;
            ((defined wantarray) ?
                ((wantarray) ?
                    (@rval = $modifier_table->{around_cache}->(@_))
		 :
                    ($rval[0] = $modifier_table->{around_cache}->(@_)))
	     :
                $modifier_table->{around_cache}->(@_));
            $_->(@_) for @{$after};
            return unless defined wantarray;
            return wantarray ? @rval : $rval[0];
        }
    }
    else {
        $modifier_table->{cache} = $modifier_table->{around_cache};
    }
};
my $compile_around_method = sub {{
    my $f1 = pop;
    return $f1 unless @_;
    my $f2 = pop;
    push @_, sub { $f2->( $f1, @_ ) };
    redo;
}};

sub method_modifier {
    my($caller, $method) = @_;
    return unless $METADATA->{$caller};

    my $code = $caller->can($method);
    croak sprintf("Could not load class (%s) because : The method '%s' is not found in the inheritance hierarchy for class %s", $caller, $method, $caller)
        unless $code;

    my $modifier_table = $METADATA->{$caller}->{'%method_modifier_applied'}->{$method};
    $modifier_table->{before}       ||= [];
    $modifier_table->{after}        ||= [];
    $modifier_table->{around}       ||= [];
    $modifier_table->{cache}        ||= $code;
    $modifier_table->{orig}         ||= $code;
    $modifier_table->{around_cache} ||= $code;

    if (@{ $modifier_table->{around} }) {
        $modifier_table->{around_cache} = $compile_around_method->(
            reverse(@{ $modifier_table->{around} }),
            $modifier_table->{orig}
        );
    }

    $_build_wrapped_method->($modifier_table);

    no strict 'refs';
    no warnings 'redefine';
    *{"$caller\::$method"} = sub { goto $modifier_table->{cache} };
}

package # hide pause
    Class::Component::Component::Moosenize::Role;
use strict;
use warnings;
use Carp::Clan qw/Class::Component/;

sub import_after {}
1;


__END__

=head1 NAME

Class::Component::Component::Moosenize - you can Moose like Plugin code

=head1 SYNOPSIS

=head1 EXPORT METHODS

=over 4

=item requires, with

  package MyApp;
  use Class::Component;
  __PACKAGE__->load_components(qw/ Moosenize /);

  package MyApp::Plugin;
  use base 'Class::Component::Plugin';
  use MyApp::Role;
  requires 'foo';
  requires bar => ['Method'], baz => ['+Foo::MyAttribute'];
  requires hop => +{ Method => 'jump' };

  package MyApp::Role;

  package MyApp::Role::Blah;
  use MyApp::Role;
  requires 'blah';

  package MyApp::Plugin::Hoge;
  use base qw( MyApp::Plugin  );
  use MyApp::Role;
  with 'MyApp::Role::Blah';

  sub foo { # simple method
  }

  sub bar { # same "sub bar :Method {"
  }

  sub baz { # same "sub baz :+Foo::MyAttribute {"
  }

  sub hop { # same "sub hop :Method('jump') {"
  }

  sub blah { # simple method
  }


=item before after around

See also L<Moose> and L<Moose::Role>

=back

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 SEE ALSO

L<Class::Component>, L<Moose>, L<Moose::Role>, L<Class::MOP>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
