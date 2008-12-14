package Template::Declare::TagSet::RDF::EM;

use strict;
use warnings;
use base 'Template::Declare::TagSet';
#use Smart::Comments;

sub get_tag_list {
    return [ qw{
        aboutURL    contributor    creator
        description    developer    file
        hidden    homepageURL    iconURL
        id    locale    localized
        maxVersion    minVersion    name
        optionsURL    package    requires
        skin    targetApplication    targetPlatform
        translator    type    updateURL
        version
    } ];
}

1;
__END__

=head1 NAME

Template::Declare::TagSet::RDF::EM - Tag set for Mozilla's em-rdf

=head1 SYNOPSIS

    # normal use on the user side:
    use base 'Template::Declare';
    use Template::Declare::Tags
         'RDF::EM' => { namespace => 'em' }, 'RDF';

    template foo => sub {
        RDF {
            attr {
                'xmlns' => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                'xmlns:em' => 'http://www.mozilla.org/2004/em-rdf#'
            }
            Description {
                attr { about => 'urn:mozilla:install-manifest' }
                em::id { 'foo@bar.com' }
                em::version { '1.2.0' }
                em::type { '2' }
                em::creator { 'Agent Zhang' }
            }
        }
    };

=head1 INHERITANCE

    Template::Declare::TagSet::RDF::EM
        isa Template::Declare::TagSet

=head1 METHODS

=over

=item C<< $obj = Template::Declare::TagSet::RDF::EM->new({ namespace => $XML_namespace, package => $Perl_package }) >>

Constructor inherited from L<Template::Declare::TagSet>.

=item C<< $list = $obj->get_tag_list() >>

Returns an array ref for the tag names.

Currently the following tags are supported:

        aboutURL    contributor    creator
        description    developer    file
        hidden    homepageURL    iconURL
        id    locale    localized
        maxVersion    minVersion    name
        optionsURL    package    requires
        skin    targetApplication    targetPlatform
        translator    type    updateURL
        version

This list may be not exhaustive; if you find some
important missing ones, please let us know :)

=back

=head1 AUTHOR

Agent Zhang <agentzh@yahoo.cn>

=head1 SEE ALSO

L<Template::Declare::TagSet>, L<Template::Declare::TagSet::RDF>, L<Template::Declare::TagSet::XUL>, L<Template::Declare::Tags>, L<Template::Declare>.

