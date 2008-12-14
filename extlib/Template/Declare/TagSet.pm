package Template::Declare::TagSet;

use strict;
use warnings;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_ro_accessors(
    qw{ namespace package implementor }
);

sub get_alternate_spelling {
    undef;
}

sub get_tag_list {
    [];
}

# specify whether "<tag></tag>" can be combined to "<tag />"
sub can_combine_empty_tags {
    1;
}

1;
__END__

=head1 NAME

Template::Declare::TagSet - Base class for tag set classes used by Template::Declare::Tags

=head1 SYNOPSIS

    package My::TagSet;
    use base 'Template::Declare::TagSet';

    # returns an array ref for the tag names
    sub get_tag_list {
        [ qw/ html body tr td table
             base meta link hr
            / ]
    }

    # prevents potential naming conflicts:
    sub get_alternate_spelling {
        my ($self, $tag) = @_;
        return 'row' if $tag eq 'tr';
        return 'cell' if $tag eq 'td';
    }

    # Specifies whether "<tag></tag>" can be
    # combined to "<tag />":
    sub can_combine_empty_tags {
        my ($self, $tag) = @_;
        $tag =~ /^ base | meta | link | hr $/x;
    }

=head1 METHODS

=over

=item C<< $obj = Template::Declare::TagSet->new({ package => 'Foo::Bar', namespace => undef }); >>

Constructor created by C<Class::Accessor::Fast>,
accepting an optional option list.

=item C<< $list = $obj->get_tag_list() >>

Returns an array ref for the tag names.

=item C<< $bool = $obj->get_alternate_spelling($tag) >>

Returns whether a tag has an alternative spelling. Basically
it provides a way to work around naming conflicts, for
examples, the C<tr> tag in HTML conflicts with the C<tr>
operator in Perl and the C<template> tag in XUL conflicts
with the C<template> sub exported by C<Template::Declare::Tags>.

=item C<< $bool = $obj->can_combine_empty_tags($tag) >>

Specifies whether "<tag></tag>" can be combined into a single
token "<tag />".

Always returns true (value 1) in this base class.

But there's some cases where you want to override the
deafault implementation. For example,
C<< Template::Declare::TagSet::HTML->can_combine_empty_tags('img') >> returns true (1) since C<< <img src="..." /> >> is always
required for HTML pages.

=back

=head1 ACCESSORS

This class has two read-only accessors:

=over

=item C<< $obj->package() >>

Retrieves the value of the C<package> option set via
the constructor.

=item C<< $obj->namespace() >>

Retrieves the value of the C<namespace> option set by
the constructor.

=back

=head1 AUTHOR

Agent Zhang <agentzh@yahoo.cn>.

=head1 SEE ALSO

L<Template::Declare::TagSet::HTML>, L<Template::Declare::TagSet::XUL>, L<Template::Declare::Tags>,
L<Template::Declare>.

