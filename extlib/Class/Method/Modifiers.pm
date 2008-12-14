#!/usr/bin/env perl
package Class::Method::Modifiers;
use strict;
use warnings;

use MRO::Compat;

our $VERSION = '1.01';

use base 'Exporter';
our @EXPORT = qw(before after around);
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = (
    moose => [qw(before after around)],
    all   => \@EXPORT_OK,
);

use Carp 'confess';

our %MODIFIER_CACHE;

sub _install_modifier {
    my $into  = shift;
    my $type  = shift;
    my $code  = pop;
    my @names = @_;

    for my $name (@names) {
        my $hit = $into->can($name)
            or confess "The method '$name' is not found in the inheritance hierarchy for class $into";

        my $qualified = $into.'::'.$name;
        my $cache = $MODIFIER_CACHE{$into}{$name} ||= {
            before => [],
            after  => [],
            around => [],
        };

        # this must be the first modifier we're installing
        if (!exists($MODIFIER_CACHE{$into}{$name}{"orig"})) {
            no strict 'refs';

            # grab the original method (or undef if the method is inherited)
            $cache->{"orig"} = *{$qualified}{CODE};

            # the "innermost" method, the one that "around" will ultimately wrap
            $cache->{"wrapped"} = $cache->{"orig"} || $hit; #sub {
            #    # we can't cache this, because new methods or modifiers may be
            #    # added between now and when this method is called
            #    for my $package (@{ mro::get_linear_isa($into) }) {
            #        next if $package eq $into;
            #        my $code = *{$package.'::'.$name}{CODE};
            #        goto $code if $code;
            #    }
            #    confess "$qualified\::$name disappeared?";
            #};
        }

        # keep these lists in the order the modifiers are called
        if ($type eq 'after') {
            push @{ $cache->{$type} }, $code;
        }
        else {
            unshift @{ $cache->{$type} }, $code;
        }

        # wrap the method with another layer of around. much simpler than
        # the Moose equivalent. :)
        if ($type eq 'around') {
            my $method = $cache->{wrapped};
            $cache->{wrapped} = sub {
                $code->($method, @_);
            };
        }

        # install our new method which dispatches the modifiers, but only
        # if a new type was added
        if (@{ $cache->{$type} } == 1) {

            # avoid these hash lookups every method invocation
            my $before  = $cache->{"before"};
            my $after   = $cache->{"after"};

            # this is a coderef that changes every new "around". so we need
            # to take a reference to it. better a deref than a hash lookup
            my $wrapped = \$cache->{"wrapped"};

            my $generated = 'sub {';

            # before is easy, it doesn't affect the return value(s)
            $generated .= '$_->(@_) for @$before;' if @$before;

            if (@$after) {
                $generated .= '
                    my @ret;
                    if (wantarray) {
                        @ret = $$wrapped->(@_);
                    }
                    else {
                        $ret[0] = $$wrapped->(@_);
                    }

                    $_->(@_) for @$after;

                    return wantarray ? @ret : $ret[0];
                ';
            }
            else {
                $generated .= '$$wrapped->(@_);';
            }

            $generated .= '}';

            no strict 'refs';
            no warnings 'redefine';
            *$qualified = eval $generated;
        };
    }
}

sub before {
    _install_modifier(scalar(caller), 'before', @_);
}

sub after {
    _install_modifier(scalar(caller), 'after', @_);
}

sub around {
    _install_modifier(scalar(caller), 'around', @_);
}

1;

__END__

=head1 NAME

Class::Method::Modifiers - provides Moose-like method modifiers

=head1 SYNOPSIS

    package Child;
    use parent 'Parent';
    use Class::Method::Modifiers;

    sub new_method { }

    before 'old_method' => sub {
        carp "old_method is deprecated, use new_method";
    };

    around 'other_method' => sub {
        my $orig = shift;
        my $ret = $orig->(@_);
        return $ret =~ /\d/ ? $ret : lc $ret;
    };

=head1 DESCRIPTION

Method modifiers are a powerful feature from the CLOS (Common Lisp Object
System) world.

In its most basic form, a method modifier is just a method that calls
C<< $self->SUPER::foo(@_) >>. I for one have trouble remembering that exact
invocation, so my classes seldom re-dispatch to their base classes. Very bad!

C<Class::Method::Modifiers> provides three modifiers: C<before>, C<around>, and
C<after>. C<before> and C<after> are run just before and after the method they
modify, but can not really affect that original method. C<around> is run in
place of the original method, with a hook to easily call that original method.
See the C<MODIFIERS> section for more details on how the particular modifiers
work.

One clear benefit of using C<Class::Method::Modifiers> is that you can define
multiple modifiers in a single namespace. These separate modifiers don't need
to know about each other. This makes top-down design easy. Have a base class
that provides the skeleton methods of each operation, and have plugins modify
those methods to flesh out the specifics.

Parent classes need not know about C<Class::Method::Modifiers>. This means you
should be able to modify methods in I<any> subclass. See
L<Term::VT102::ZeroBased> for an example of subclassing with CMM.

In short, C<Class::Method::Modifiers> solves the problem of making sure you
call C<< $self->SUPER::foo(@_) >>, and provides a cleaner interface for it.

As of version 1.00, C<Class::Method::Modifiers> is faster than L<Moose>. See
C<benchmark/method_modifiers.pl> in the L<Moose> distribution.

=head1 MODIFIERS

=head2 before method(s) => sub { ... }

C<before> is called before the method it is modifying. Its return value is
totally ignored. It receives the same C<@_> as the the method it is modifying
would have received. You can modify the C<@_> the original method will receive
by changing C<$_[0]> and friends (or by changing anything inside a reference).
This is a feature!

=head2 after method(s) => sub { ... }

C<after> is called after the method it is modifying. Its return value is
totally ignored. It receives the same C<@_> as the the method it is modifying
received, mostly. The original method can modify C<@_> (such as by changing
C<$_[0]> or references) and C<after> will see the modified version. If you
don't like this behavior, specify both a C<before> and C<after>, and copy the
C<@_> during C<before> for C<after> to use.

=head2 around method(s) => sub { ... }

C<around> is called instead of the method it is modifying. The method you're
overriding is passed in as the first argument (called C<$orig> by convention).
Watch out for contextual return values of C<$orig>.

You can use C<around> to:

=over 4

=item Pass C<$orig> a different C<@_>

    around 'method' => sub {
        my $orig = shift;
        my $self = shift;
        $orig->($self, reverse @_);
    };

=item Munge the return value of C<$orig>

    around 'method' => sub {
        my $orig = shift;
        ucfirst $orig->(@_);
    };

=item Avoid calling C<$orig> -- conditionally

    around 'method' => sub {
        my $orig = shift;
        return $orig->(@_) if time() % 2;
        return "no dice, captain";
    };

=back

=head1 NOTES

All three normal modifiers; C<before>, C<after>, and C<around>; are exported
into your namespace by default. You may C<use Class::Method::Modifiers ()> to
avoid thrashing your namespace. I may steal more features from L<Moose>, namely
C<super>, C<override>, C<inner>, C<augment>, and whatever the L<Moose> folks
come up with next.

Note that the syntax and semantics for these modifiers is directly borrowed
from L<Moose> (the implementations, however, are not).

L<Class::Trigger> shares a few similarities with C<Class::Method::Modifiers>,
and they even have some overlap in purpose -- both can be used to implement
highly pluggable applications. The difference is that L<Class::Trigger>
provides a mechanism for easily letting parent classes to invoke hooks defined
by other code. C<Class::Method::Modifiers> provides a way of
overriding/augmenting methods safely, and the parent class need not know about
it.

=head1 CAVEATS

It is erroneous to modify a method that doesn't exist in your class's
inheritance hierarchy. If this occurs, an exception will be thrown when
the modifier is defined.

It doesn't yet play well with C<caller>. There are some todo tests for this.
Don't get your hopes up though!

=head1 VERSION

This module was bumped to 1.00 following a complete reimplementation, to
indicate breaking backwards compatibility. The "guard" modifier was removed,
and the internals are completely different.

The new version is a few times faster with half the code. It's now even faster
than Moose.

Any code that just used modifiers should not change in behavior, except to
become more correct. And, of course, faster. :)

=head1 SEE ALSO

L<Moose>, L<Class::Trigger>, L<Class::MOP::Method::Wrapped>, L<MRO::Compat>,
CLOS

=head1 AUTHOR

Shawn M Moore, C<< <sartak at gmail.com> >>

=head1 BUGS

Please report any bugs through RT: email
C<bug-class-method-modifiers at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-Method-Modifiers>.

=head1 ACKNOWLEDGEMENTS

Thanks to Stevan Little for L<Moose>, I would never have known about
method modifiers otherwise.

Thanks to Matt Trout and Stevan Little for their advice.

=head1 COPYRIGHT & LICENSE

Copyright 2007-2008 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

