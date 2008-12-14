package Template::Declare::TagSet::HTML;

use strict;
use warnings;
use base 'Template::Declare::TagSet';
#use Smart::Comments;

our %AlternateSpelling = (
    tr   => 'row',
    td   => 'cell',
    base => 'html_base',
);

sub get_alternate_spelling {
    my ($self, $tag) = @_;
    $AlternateSpelling{$tag};
}

# no need to load CGI, really
#sub get_tag_list {
#    my @tags = map { lc($_) } map { @{$_||[]} }
#        @CGI::EXPORT_TAGS{
#                qw/:html2 :html3 :html4 :netscape :form/
#        };
#    return [ @tags, qw/form canvas/ ];
#}

sub get_tag_list {
    return [qw(
        h1 h2 h3 h4 h5 h6 p br hr ol ul li dl dt dd menu code var strong em tt
        u i b blockquote pre img a address cite samp dfn html head base body
        link nextid title meta kbd start_html end_html input select option
        comment charset escapehtml div table caption th td tr tr sup sub
        strike applet param nobr embed basefont style span layer ilayer font
        frameset frame script small big area map abbr acronym bdo col colgroup
        del fieldset iframe ins label legend noframes noscript object optgroup
        q thead tbody tfoot blink fontsize center textfield textarea filefield
        password_field hidden checkbox checkbox_group submit reset defaults
        radio_group popup_menu button autoescape scrolling_list image_button
        start_form end_form startform endform start_multipart_form
        end_multipart_form isindex tmpfilename uploadinfo url_encoded
        multipart form canvas
    )]
}

sub can_combine_empty_tags {
    my ($self, $tag) = @_;
    $tag
        =~ m{^ (?: base | meta | link | hr | br | param | img | area | input | col ) $}x;
}

1;
__END__

=head1 NAME

Template::Declare::TagSet::HTML - Tag set for HTML

=head1 SYNOPSIS

    # normal use on the user side:
    use base 'Template::Declare';
    use Template::Declare::Tags 'HTML';

    template foo => sub {
        html {
            body {
            }
        }
    };

    # in Template::Declare::Tags:

    use Template::Declare::TagSet::HTML;
    my $tagset = Template::Declare::TagSet::HTML->new(
        { package => 'html', namespace => 'html' }
    );
    my $list = $tagset->get_tag_list();
    print "@$list";

    my $altern = $tagset->get_alternate_spelling('tr');
    if ( defined $altern ) {
        print $altern;
    }

    if ( $tagset->can_combine_empty_tags('img') ) {
        print "<img src='blah.gif' />";
    }

=head1 INHERITANCE

    Template::Declare::TagSet::HTML
        isa Template::Declare::TagSet

=head1 METHODS

=over

=item C<< $obj = Template::Declare::TagSet::HTML->new({ namespace => $XML_namespace, package => $Perl_package }) >>

Constructor inherited from L<Template::Declare::TagSet>.

=item C<< $list = $obj->get_tag_list() >>

Returns an array ref for the tag names.

Out of the box, C<Template::Declare::TagSet::HTML> returns the
C<:html2 :html3 :html4 :netscape> and C<:form>
tagsets from CGI.pm.

=item C<< $bool = $obj->get_alternate_spelling($tag) >>

Returns the alternative spelling for a given tag if any or
undef otherwise. Currently, C<tr> is mapped to C<row>,
C<td> is mapped to C<cell>, and C<base> is mapped to
C<html_base>.

Because C<tr> is reserved by the perl interpreter for
the operator of that name. We can't override it. And
we override C<td> as well so as to keep consistent.

For similar reasons, 'base' often gives us trouble too ;)

=item C<< $bool = $obj->can_combine_empty_tags($tag) >>

=back

=head1 AUTHOR

Agent Zhang <agentzh@yahoo.cn>

=head1 SEE ALSO

L<Template::Declare::TagSet>, L<Template::Declare::TagSet::XUL>, L<Template::Declare::TagSet::RDF>, L<Template::Declare::Tags>, L<Template::Declare>.

