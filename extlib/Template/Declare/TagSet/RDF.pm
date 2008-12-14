package Template::Declare::TagSet::RDF;

use strict;
use warnings;
use base 'Template::Declare::TagSet';
#use Smart::Comments;

sub get_tag_list {
    return [ qw{
        Alt    Bag    Description
        List    Property    RDF
        Seq    Statement    XMLLiteral
        about   li
        first    nil    object
        predicate    resource    rest
        subject    type    value
    }, (map { "_$_" } 1..10) ];
}


1;
__END__

=head1 NAME

Template::Declare::TagSet::RDF - Tag set for RDF

=head1 SYNOPSIS

    # normal use on the user side:
    use base 'Template::Declare';
    use Template::Declare::Tags
         RDF => { namespace => 'rdf' };

    template foo => sub {
        rdf::RDF {
            attr { 'xmlns:rdf' => "http://www.w3.org/1999/02/22-rdf-syntax-ns#" }
            rdf::Description {
                attr { about => "Matilda" }
                #...
            }
        }
    };

=head1 INHERITANCE

    Template::Declare::TagSet::RDF
        isa Template::Declare::TagSet

=head1 METHODS

=over

=item C<< $obj = Template::Declare::TagSet::RDF->new({ namespace => $XML_namespace, package => $Perl_package }) >>

Constructor inherited from L<Template::Declare::TagSet>.

=item C<< $list = $obj->get_tag_list() >>

Returns an array ref for the tag names.

Currently the following tags are supported:

        Alt    Bag    Description
        List    Property    RDF
        Seq    Statement    XMLLiteral
        about   li
        first    nil    object
        predicate    resource    rest
        subject    type    value
        _1 _2 _3 _4 _5 _6 _7 _8 _9 _10

This list may be not exhaustive; if you find some
important missing ones, please let us know :)

=back

=head1 AUTHOR

Agent Zhang <agentzh@yahoo.cn>

=head1 SEE ALSO

L<Template::Declare::TagSet>, L<Template::Declare::TagSet::HTML>, L<Template::Declare::TagSet::XUL>, L<Template::Declare::Tags>, L<Template::Declare>.

=begin comment

Tag set for RDF Schema:

    Class    Container    ContainerMembershipProperty
    Datatype    Literal    Resource
    comment    domain    isDefinedBy
    label    member    range
    seeAlso    subClassOf    subPropertyOf

=cut
