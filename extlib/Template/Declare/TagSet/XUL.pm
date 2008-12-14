package Template::Declare::TagSet::XUL;

use strict;
use warnings;
#use Smart::Comments;
use base 'Template::Declare::TagSet';

our %AlternateSpelling = (
    template => 'xul_tempalte',
);

sub get_alternate_spelling {
    my ($self, $tag) = @_;
    $AlternateSpelling{$tag};
}

sub get_tag_list {
    return [ qw{
  action  arrowscrollbox  bbox  binding
  bindings  body  box  broadcaster
  broadcasterset  browser  button  caption
  checkbox  children  colorpicker  column
  columns  command  commandset  conditions
  constructor  content  deck  description
  destructor  dialog  dialogheader  editor
  field  getter  grid  grippy
  groupbox  handler  handlers  hbox
  iframe  image  implementation  key
  keyset  label  listbox  listcell
  listcol  listcols  listhead  listheader
  listitem  member  menu  menubar
  menuitem  menulist  menupopup  menuseparator
  method  observes  overlay  page
  parameter  popup  popupset  progressmeter
  property  radio  radiogroup  rdf
  resizer  resources  richlistbox row  rows
  rule  script  scrollbar  scrollbox
  separator  setter  spacer  splitter
  stack  statusbar  statusbarpanel  stringbundle
  stringbundleset  stylesheet  tab  tabbox
  tabbrowser  tabpanel  tabpanels  tabs
  template  textbox  textnode  titlebar
  toolbar  toolbarbutton  toolbargrippy  toolbaritem
  toolbarpalette  toolbarseparator  toolbarset  toolbarspacer
  toolbarspring  toolbox  tooltip  tree
  treecell  treechildren  treecol  treecols
  treeitem  treerow  treeseparator  triple
  vbox  window  wizard  wizardpage
    } ];
}

1;
__END__

=head1 NAME

Template::Declare::TagSet::XUL - Tag set for XUL

=head1 SYNOPSIS

    use Template::Declare::TagSet::XUL;
    my $tagset = Template::Declare::TagSet::XUL->new(
        namespace => undef, package => 'self');
    my $list = $tagset->get_tag_list();
    print "@$list";

    my $altern = $tagset->get_alternate_spelling('template');
    if ( defined $altern ) {
        print $altern;
    }

    if ( $tagset->can_combine_empty_tags('button') ) {
        print "<button label='OK' />";
    }

    # normal use
    package MyApp::Templates;
    use Template::Declare::Tags qw/ XUL /;
    use base 'Template::Declare';
    # ...

=head1 INHERITANCE

   Template::Declare::TagSet::XUL
        isa Template::Declare::TagSet

=head1 METHODS

=over

=item C<< $obj = Template::Declare::TagSet::XUL->new({ namespace => $XML_namespace, package => $Perl_package }) >>

Constructor inherited from L<Template::Declare::TagSet>.

=item C<< $list = $obj->get_tag_list() >>

Returns an array ref for the tag names.

The tag list was extracted from L<http://www.xulplanet.com/references/elemref/refall_elemref.xml> (only C<< <element name='...'> >> were recognized).

=item C<< $bool = $obj->get_alternate_spelling($tag) >>

Returns the alternative spelling for a given tag if any or
undef otherwise. Currently, C<template> is mapped to C<xul_template> because there is already a C<template> sub exported
by L<Template::Declare::Tags>.

=item C<< $bool = $obj->can_combine_empty_tags($tag) >>

Always returns true (inherited directly from the base class,
L<Template::Declare::TagSet>.

=back

=head1 AUTHOR

Agent Zhang <agentzh@yahoo.cn>

=head1 SEE ALSO

L<Template::Declare::TagSet>, L<Template::Declare::TagSet::HTML>, L<Template::Declare::Tags>, L<Template::Declare>.

