use 5.006;
use warnings;
use strict;
#use Smart::Comments;
#use Smart::Comments '####';

package Template::Declare::Tags;

our $VERSION = '0.27';

use Template::Declare;
use vars qw( @EXPORT_OK $PRIVATE $self @TagSubs );
use base 'Exporter';
use Carp qw(carp croak);
use Symbol 'qualify_to_ref';

our @EXPORT
    = qw( with template private show show_page attr outs
          outs_raw in_isolation $self under
          get_current_attr xml_decl
          smart_tag_wrapper current_template create_wrapper );
our @TAG_SUB_LIST;
*TagSubs = \@TAG_SUB_LIST;  # For backward compatibility only

our %ATTRIBUTES       = ();
our %ELEMENT_ID_CACHE = ();
our $TAG_NEST_DEPTH   = 0;
our @TEMPLATE_STACK;

our $SKIP_XML_ESCAPING = 0;

sub import {
    my $self = shift;
    my @set_modules;
    if (!@_) {
        push @_, 'HTML';
    }
    ### @_
    ### caller: caller()

    # XXX We can't reset @TAG_SUB_LIST here since
    # use statements always run at BEGIN time.
    # A better approach may be install such lists
    # directly into the caller's namespace...
    #undef @TAG_SUB_LIST;

    while (@_) {
        my $lang = shift;
        my $opts;
        if (ref $_[0] and ref $_[0] eq 'HASH') {
            $opts = shift;
            $opts->{package} ||= $opts->{namespace};
            # XXX TODO: carp if the derived package already exists?
        }
        $opts->{package} ||= scalar(caller);
        my $module = $opts->{from} ||
            "Template::Declare::TagSet::$lang";

        ### Loading tag set: $module
        eval "use $module";
        if ($@) {
            warn $@;
            croak "Failed to load tagset module $module";
        }
        ### TagSet options: $opts
        my $tagset = $module->new($opts);
        my $tag_list = $tagset->get_tag_list;
        Template::Declare::Tags::install_tag($_, $tagset)
            for @$tag_list;
    }
   __PACKAGE__->export_to_level(1, $self);
}

sub _install {
    my ($override, $package, $subname, $coderef) = @_;

    my $name = $package . '::' . $subname;
    my $slot = qualify_to_ref($name);
    return if !$override and *$slot{CODE};

    no warnings 'redefine';
    *$slot = $coderef;
}

=head1 NAME

Template::Declare::Tags - Build and install XML Tag subroutines for Template::Declare

=head1 SYNOPSIS

    package MyApp::Templates;

    use base 'Template::Declare';
    use Template::Declare::Tags 'HTML';

    template main => sub {
        link {}
        table {
            row {
                cell { "Hello, world!" }
            }
        }
        img { attr { src => 'cat.gif' } }
        img { src is 'dog.gif' }
    };

    # Produces:
    # <link />
    # <table>
    #  <tr>
    #   <td>Hello, world!</td>
    #  </tr>
    # </table>
    # <img src="cat.gif" />
    # <img src="dog.gif" />

    package MyApp::Templates;

    use base 'Template::Declare';
    use Template::Declare::Tags
        'XUL', HTML => { namespace => 'html' };

    template main => sub {
        groupbox {
            caption { attr { label => 'Colors' } }
            html::div { html::p { 'howdy!' } }
            html::br {}
        }
    };

    # Produces:
    #   <groupbox>
    #    <caption label="Colors" />
    #    <html:div>
    #     <html:p>howdy!</html:p>
    #    </html:div>
    #    <html:br></html:br>
    #   </groupbox>

=head1 DESCRIPTION

C<Template::Declare::Tags> is used to generate and install
subroutines for tags into the user's namespace.

You can specify the tag sets used by providing a list of
module list in the C<use> statement:

    use Template::Declare::Tags qw/ HTML XUL /;

By default, it uses the tag set provided by L<Template::Declare::TagSet::HTML>. So

    use Template::Declare::Tags;

is equivalent to

    use Template::Declare::Tags 'HTML';

Currently L<Template::Declare> bundles the following tag sets:
L<Template::Declare::TagSet::HTML>, L<Template::Declare::TagSet::XUL>, L<Template::Declare::TagSet::RDF>, and L<Template::Declare::TagSet::RDF::EM>.

You can certainly specify your own tag set classes, as long
as they subclass L<Template::Declare::TagSet> and implement
the corresponding methods (e.g. C<get_tag_list>).

If you implement a custom tag set module named
C<Template::Declare::TagSet::Foo>.

 use Template::Declare::Tags 'Foo';

If you give the your tag set module a different name, say, C<MyTag::Foo>, then
you use the C<from> option:

 use Template::Declare::Tags Foo => { from => 'MyTag::Foo' };

Then C<Template::Declare::Tags> will no longer try to load C<Template::Declare::TagSet::Foo>
and C<MyTag::Foo> will be loaded instead.

XML namespaces are emulated by Perl packages. For
example, you can embed HTML tags within XUL using the C<html> namespace:

    package MyApp::Templates;

    use base 'Template::Declare';
    use Template::Declare::Tags
        'XUL', HTML => { namespace => 'html' };

    template main => sub {
        groupbox {
            caption { attr { label => 'Colors' } }
            html::div { html::p { 'howdy!' } }
            html::br {}
        }
    };

This will give you

       <groupbox>
        <caption label="Colors" />
        <html:div>
         <html:p>howdy!</html:p>
        </html:div>
        <html:br></html:br>
       </groupbox>

Behind the scene, C<Template::Declare::Tags>  will generate a Perl package named C<html> and install HTML tag subroutines into that package. On the other hand, XUL tag subroutines are installed into the current package, namely, C<MyApp::Templates> in the previous example.

There are cases when you want to specify a different Perl package for a perticular XML namespace name. For instance, the C<html> Perl package has already been used for other purposes in your application and you don't want to install subs there and mess things up, then the C<package> option can come to rescue:

    package MyApp::Templates;
    use base 'Template::Declare';
    use Template::Declare::Tags
        'XUL', HTML => {
            namespace => 'htm',
            package => 'MyHtml'
        };

    template main => sub {
        groupbox {
            caption { attr { label => 'Colors' } }
            MyHtml::div { MyHtml::p { 'howdy!' } }
            MyHtml::br {}
        }
    };

This code snippet will still generate something like the following:

    <groupbox>
     <caption label="Colors" />
     <htm:div>
      <htm:p>howdy!</htm:p>
     </htm:div>
     <htm:br></htm:br>
    </groupbox>

=head1 METHODS AND SUBROUTINES

=head2 template TEMPLATENAME => sub { 'Implementation' };

C<template> declares a template in the current package. You can pass
any url-legal characters in the template name. C<Template::Declare>
will encode the template as a perl subroutine and stash it to be called
with C<show()>.

(Did you know that you can have characters like ":" and "/" in your Perl
subroutine names? The easy way to get at them is with "can").

=cut

sub template ($$) {
    my $template_name  = shift;
    my $coderef        = shift;
    my $template_class = ( caller(0) )[0];

    no warnings qw( uninitialized redefine );

    # template "foo" ==> CallerPkg::_jifty_template_foo;
    # template "foo/bar" ==> CallerPkg::_jifty_template_foo/bar;
    my $codesub = sub {
        local $self = shift || $self || $template_class;
        unshift @_, $self, $coderef;
        goto $self->can('_dispatch_template');
    };

    if (wantarray) {
         # We're being called by something like private that doesn't want us to register ourselves
        return ( $template_class, $template_name, $codesub );
    } else {

       # We've been called in a void context and should register this template
        Template::Declare::register_template( $template_class, $template_name,
            $codesub );
    }

}

=head2 create_wrapper WRAPPERNAME => sub { 'Implementation' };

C<create_wrapper> declares a wrapper subroutine that can be called like a tag
sub, but can optionally take arguments to be passed to the wrapper sub. For
example, if you wanted to wrap all of the output of a template in the usual
HTML headers and footers, you can do something like this:

  package MyApp::Templates;
  use Template::Declare::Tags;
  use base 'Template::Declare';

  BEGIN {
      create_wrapper wrap => sub {
          my $code = shift;
          my %params = @_;
          html {
              head { title { outs "Hello, $params{user}!"} };
              body {
                  $code->();
                  div { outs 'This is the end, my friend' };
              };
          }
      };
  }

  template inner => sub {
      wrap {
          h1 { outs "Hello, Jesse, s'up?" };
      } user => 'Jesse';
  };

Note how the C<wrap> wrapper function is available for calling after it has
been declared in a C<BEGIN> block. Also note how you can pass arguments to the
function after the closing brace (you don't need a comma there!).

The output from the "inner" template will look something like this:

  <html>
   <head>
    <title>Hello, Jesse!</title>
   </head>
   <body>
    <h1>Hello, Jesse, s&#39;up?</h1>
    <div>This is the end, my friend</div>
   </body>
  </html>

=cut

sub create_wrapper ($$) {
    my $wrapper_name   = shift;
    my $coderef        = shift;
    my $template_class = caller;

    # Shove the code ref into the calling class.
    no strict 'refs';
    *{"$template_class\::$wrapper_name"} = sub (&;@) { goto $coderef };
}

=head2 private template TEMPLATENAME => sub { 'Implementation' };

C<private> declares that a template isn't available to be called directly from client code.

=cut

sub private (@) {
    my $class   = shift;
    my $subname = shift;
    my $code    = shift;
    Template::Declare::register_private_template( $class, $subname, $code );
}

=head2 attr HASH

With C<attr>, you can specify attributes for HTML tags.


Example:

 p {
    attr { class => 'greeting text',
           id    => 'welcome' };
    'This is a welcoming paragraph';
 }

Tag attributes can also be specified by using C<is>, as in

 p {
    class is 'greeting text';
    id    is 'welcome';
    'This is a welcoming paragraph';
 }


=cut

sub attr (&;@) {
    my $code = shift;
    my @rv   = $code->();
    while ( my ( $field, $val ) = splice( @rv, 0, 2 ) ) {

        # only defined whle in a tag context
        append_attr( $field, $val );
    }
    return @_;
}

sub append_attr {
    die "Subroutine attr failed: $_[0] => '$_[1]'\n\t".
        "(Perhaps you're using an unknown tag in the outer container?)";
}

=head2 xml_decl HASH

Emits XML declarators.

For example,

    xml_decl { 'xml', version => '1.0' };
    xml_decl { 'xml-stylesheet',  href => "chrome://global/skin/", type => "text/css" };

will produce

    <?xml version="1.0"?>
    <?xml-stylesheet href="chrome://global/skin/" type="text/css"?>

=cut

sub xml_decl (&;$) {
    my $code = shift;
    my @rv   = $code->();
    my $name = shift @rv;
    outs_raw("<?$name");
    while ( my ( $field, $val ) = splice( @rv, 0, 2 ) ) {
        # only defined whle in a tag context
        outs_raw(qq/ $field="$val"/);
    }
    outs_raw("?>\n");
    return @_;
}

=head2 outs STUFF

C<outs> HTML-encodes its arguments and appends them to C<Template::Declare>'s output buffer.


=cut

#sub outs { outs_raw( map { _postprocess($_); } grep {defined} @_ ); }

=head2 outs_raw STUFF

C<outs_raw> appends its arguments to C<Template::Declare>'s output buffer without doing any HTML escaping.

=cut

#sub outs_raw { Template::Declare->buffer->append( join( '', grep {defined} @_ )); return ''; }

sub outs     { _outs( 0, @_ ); }
sub outs_raw { _outs( 1, @_ ); }

sub _outs {
    my $raw     = shift;
    my @phrases = (@_);
    my $buf;
    Template::Declare->new_buffer_frame;

    foreach my $item ( grep {defined} @phrases ) {

        Template::Declare->new_buffer_frame;
        my $returned =
            ref($item) eq 'CODE'
            ? $item->()
            : ( $raw ? $item : _postprocess($item) ) || '';
        my $content = Template::Declare->buffer->data || '';
        Template::Declare->end_buffer_frame;
        Template::Declare->buffer->append( $content . $returned );
    }

    $buf = Template::Declare->buffer->data || '';
    Template::Declare->end_buffer_frame;
    if ( defined wantarray and not wantarray ) {
        return $buf;
    } else {
        Template::Declare->buffer->append($buf);

    }
    return '';
}

=head2 get_current_attr

Help! I'm deprecated/

=cut

sub get_current_attr ($) {
    $ATTRIBUTES{ $_[0] };
}


=head2 install_tag TAGNAME, TAGSET

Sets up TAGNAME as a tag that can be used in user templates. TAGSET is an instance of a subclass for L<Template::Declare::TagSet>.

=cut

sub install_tag {
    my $tag  = $_[0]; # we should not do lc($tag) here :)
    my $name = $tag;
    my $tagset = $_[1];

    my $alternative = $tagset->get_alternate_spelling($tag);
    if ( defined $alternative ) {
        _install(
            0, # do not override
            scalar(caller), $tag,
            sub (&) {
                die "$tag {...} is invalid; use $alternative {...} instead.\n";
            }
        );
        ### Exporting place-holder sub: $name
        # XXX TODO: more checking here
        if ($name !~ /^(?:base|tr)$/) {
            push @EXPORT, $name;
            push @TAG_SUB_LIST, $name;
        }
        $name = $alternative or return;
    }

    # We don't need this since we directly install
    # subs into the target package.
    #push @EXPORT, $name;
    push @TAG_SUB_LIST, $name;

    no strict 'refs';
    no warnings 'redefine';
    #### Installing tag: $name
    # XXX TODO: use sub _install to insert subs into the caller's package so as to support XML packages
    my $code  = sub (&;$) {
        local *__ANON__ = $tag;
        if ( defined wantarray and not wantarray ) {

            # Scalar context - return a coderef that represents ourselves.
            my @__    = @_;
            my $_self = $self;
            my $sub   = sub {
                local $self     = $_self;
                local *__ANON__ = $tag;
                _tag($tagset, @__);
            };
            bless $sub, 'Template::Declare::Tag';
            return $sub;
        } else {
            _tag($tagset, @_);
        }
    };
    _install(
        1, # do override the existing sub with the same name
        $tagset->package => $name => $code
    );
}


=head2 with

C<with> is an alternative way to specify attributes for a tag:

    with ( id => 'greeting', class => 'foo' ),
        p { 'Hello, World wide web' };


The standard way to do this is:

    p { attr { id => 'greeting', class => 'foo' }
        'Hello, World wide web' };


=cut

sub with (@) {
    %ATTRIBUTES = ();
    while ( my ( $key, $val ) = splice( @_, 0, 2 ) ) {
        no warnings 'uninitialized';
        $ATTRIBUTES{$key} = $val;

        if ( lc($key) eq 'id' ) {
            if ( $ELEMENT_ID_CACHE{$val}++ ) {
                warn
                    "HTML appears to contain illegal duplicate element id: $val";
            }
        }

    }
    wantarray ? () : '';
}

=head2 smart_tag_wrapper

  # create a tag that has access to the arguments set with with.
  sub sample_smart_tag (&) {
      my $code = shift;

      smart_tag_wrapper {
          my %args = @_; # set using 'with'
          outs( 'keys: ' . join( ', ', sort keys %args) . "\n" );
          $code->();
      };
  }

  # use it
  with ( foo => 'bar', baz => 'bundy' ),
    sample_smart_tag {
      outs( "Hello, World!\n" );
    };

  # output would be
  keys: baz, foo
  Hello, World!

The smart tag wrapper allows you to create code that has access to the arguments
set using 'with', it passes them in to the wrapped code in C<@_>. It also takes
care of putting the output in the right place and tidying up after itself.

=cut

sub smart_tag_wrapper (&) {
    my $coderef = shift;
    my $buf     = "\n";

    Template::Declare->new_buffer_frame;

    my %attr = %ATTRIBUTES;
    %ATTRIBUTES = ();                              # prevent leakage

    my $last = join '',    #
        map { ref($_) ? $_ : _postprocess($_) }    #
        $coderef->(%attr);


    if ( length( Template::Declare->buffer->data ) ) {

        # We concatenate to force scalarization when $last or
        # $Template::Declare->buffer is solely a Jifty::Web::Link
        $buf .= Template::Declare->buffer->data;
    } elsif ( length $last ) {
        $buf .= $last;
    }

    Template::Declare->end_buffer_frame;
    Template::Declare->buffer->append($buf);

    return '';
}

sub _tag {
    my $tagset    = shift;
    my $code      = shift;
    my $more_code = shift;
    my ($package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
        )
        = caller(1);

    # This is the hash of attributes filled in by attr() calls in the code;

    my $tag = $subroutine;
    $tag =~ s/^.*\:\://;
    # "html:foo"
    $tag = $tagset->namespace . ":$tag"
        if defined $tagset->namespace;

    my $buf = "\n" . ( " " x $TAG_NEST_DEPTH ) . "<$tag"
        . join( '',
        map { qq{ $_="} . ( $ATTRIBUTES{$_} || '' ) . qq{"} }
            sort keys %ATTRIBUTES );

    my $had_content = 0;

    {
        no warnings qw( uninitialized redefine once );

        local *is::AUTOLOAD = sub {
            shift;

            my $field = our $AUTOLOAD;
            $field =~ s/.*:://;

            $field =~ s/__/:/g;   # xml__lang  is 'foo' ====> xml:lang="foo"
            $field =~ s/_/-/g;    # http_equiv is 'bar' ====> http-equiv="bar"

            # Squash empty values, but not '0' values
            my $val = join( ' ', grep { defined $_ && $_ ne '' } @_ );

            append_attr( $field, $val );
        };

        local *append_attr = sub {
            my $field = shift;
            my $val   = shift;

            $buf .= ' ' . $field . q{="} . _postprocess($val, 1) . q{"};
            wantarray ? () : '';
        };

        local $TAG_NEST_DEPTH = $TAG_NEST_DEPTH + 1;
        %ATTRIBUTES = ();
        Template::Declare->new_buffer_frame;
        my $last = join '', map { ref($_) ? $_ : _postprocess($_) } $code->();

        if ( length( Template::Declare->buffer->data ) ) {

# We concatenate to force scalarization when $last or $Template::Declare->buffer is solely a Jifty::Web::Link
            $buf .= '>' . Template::Declare->buffer->data;
            $had_content = 1;
        } elsif ( length $last ) {
            $buf .= '>' . $last;
            $had_content = 1;
        } else {
            $had_content = 0;
        }

        Template::Declare->end_buffer_frame;

    }

    if ($had_content) {
        $buf .= "\n" . ( " " x $TAG_NEST_DEPTH ) if ( $buf =~ /\>$/ );
        $buf .= "</$tag>";
    } elsif ( $tagset->can_combine_empty_tags($tag) ) {
        $buf .= " />";
    } else {
        # Otherwise we supply a closing tag.
        $buf .= "></$tag>";
    }

    Template::Declare->buffer->append($buf);
    return ( ref($more_code) && $more_code->isa('CODE') )
        ? $more_code->()
        : '';
}

=head2 show [$template_name or $template_coderef], args

C<show> displays templates. C<args> will be passed directly to the
template.

C<show> can either be called with a template name or a package/object
and a template.  (It's both functional and OO.)

If called from within a Template::Declare subclass, then private
templates are accessible and visible. If called from something that
isn't a Template::Declare, only public templates wil be visible.

From the outside world, users can either call
C<Template::Declare->show()> or C<Template::Declare::tags::show()> to
render a publicly visible template.

"private" templates may only be called from within the
C<Template::Declare> package.

=cut

sub show {
    my $template = shift;
    my $args  = \@_;
    my $data;

    # if we're inside a template, we should show private templates
    if ( caller->isa('Template::Declare') ) {
       _show_template( $template, 1, $args );
        return Template::Declare->buffer->data;
    } else {
        show_page( $template, $args);
    }

}



sub show_page {
    my $template        = shift;
    my $args = \@_;
    my $INSIDE_TEMPLATE = 0;

    # if we're inside a template, we should show private templates
    Template::Declare->new_buffer_frame;
    _show_template( $template, 0, $args );
    my $data = Template::Declare->buffer->data;
    Template::Declare->end_buffer_frame;
    %ELEMENT_ID_CACHE = ();    # We're done. we can clear the cache
    if (not defined wantarray()) {
        Template::Declare->buffer->append($data);
        return undef;
     } else {
        return $data;
     }
}

sub _resolve_relative_template_path {
    my $template = shift;

    return $template if ( $template =~ '^\/' );
    my $parent = current_template();

    my @parent   = split( '/', $parent );
    my @template = split( '/', $template );

    @template = grep { $_ !~ /^\.$/} @template; # Get rid of "." entries

    # Let's find out how many levels they want to pop up
    my @uplevels = grep { /^\.\.$/ } @template;
    @template = grep { $_ !~ /^\.\.$/ } @template;



    pop @parent;            # Get rid of the parent's template name
    pop @parent for @uplevels;
    return (join( '/', @parent, @template ) );

}


=head2 current_template

Returns the absolute path of the current template

=cut

sub current_template {
    return $TEMPLATE_STACK[-1] || '';
}


sub _show_template {
    my $template        = shift;
    my $inside_template = shift;
    my $args = shift;
    local @TEMPLATE_STACK  = @TEMPLATE_STACK;
    $template = _resolve_relative_template_path($template);
    push @TEMPLATE_STACK, $template;

    my $callable =
        ( ref($template) && $template->isa('Template::Declare::Tag') )
        ? $template
        : Template::Declare->resolve_template( $template, $inside_template );

    # If the template was not found let the user know.
    unless ($callable) {
        my $msg = "The template '$template' could not be found";
        $msg .= " (it might be private)" if !$inside_template;
        carp $msg;
        return '';
    }

    if (my $instrumentation = Template::Declare->around_template) {
        $instrumentation->(
            sub { &$callable($self, @$args) },
            $template,
            $args,
            $callable,
        );
    }
    else {
        &$callable($self, @$args);
    }

    return;
}

sub _postprocess {
    my $val = shift;
    my $skip_postprocess = shift;

    if ( ! $SKIP_XML_ESCAPING ) {
        no warnings 'uninitialized';
        $val =~ s/&/&#38;/g;
        $val =~ s/</&lt;/g;
        $val =~ s/>/&gt;/g;
        $val =~ s/\(/&#40;/g;
        $val =~ s/\)/&#41;/g;
        $val =~ s/"/&#34;/g;
        $val =~ s/'/&#39;/g;
    }
    $val = Template::Declare->postprocessor->($val)
        if defined($val) && !$skip_postprocess;

    return $val;
}

=head2 import 'Package' under 'path'

Import the templates from C<Package> into the subpath 'path' of the current package, clobbering any
of your own package's templates that you'd already defined.

=cut

=head2 under

C<under> is a helper function for the "import" semantic sugar.

=cut

sub under ($) { return shift }

=head1 VARIABLES

=over

=item C<< @Template::Declare::Tags::EXPORT >>

Holds the names of the static subroutines exported by this class.
tag subroutines generated from certain tag set, however,
are not included here.

=item C<< @Template::Declare::Tags::TAG_SUB_LIST >>

Contains the names of the tag subroutines generated
from certain tag set.

Note that this array won't get cleared automatically before
a another C<< use Template::Decalre::Tags >> statement.

C<@Template::Declare::Tags::TagSubs> is aliased to this
variable for backward-compatibility.

=item C<< $Template::Declare::Tags::TAG_NEST_DEPTH >>

Controls the indentation of the XML tags in the final outputs. For example, you can temporarily disable a tag's indentation by the following lines of code:

    body {
        pre {
          local $Template::Declare::Tags::TAG_NEST_DEPTH = 0;
          script { attr { src => 'foo.js' } }
        }
    }

It generates

    <body>
     <pre>
    <script src="foo.js"></script>
     </pre>
    </body>

Note that now the C<script> tag has I<no> indentation and we've got what we want ;)

=item C<< $Template::Declare::Tags::SKIP_XML_ESCAPING >>

Makes L<Template::Declare> skip the XML escaping
postprocessing entirely.

=back

=head1 SEE ALSO

L<Template::Declare::TagSet::HTML>,
L<Template::Declare::TagSet::XUL>, L<Template::Declare>.

=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com>,
Agent Zhang <agentzh@yahoo.cn>

=head1 COPYRIGHT

Copyright 2006-2007 Best Practical Solutions, LLC

=cut

package Template::Declare::Tag;

use overload '""' => \&stringify;

sub stringify {
    my $self = shift;

    if ( defined wantarray ) {
        Template::Declare->new_buffer_frame;
        my $returned = $self->();
        my $content  = Template::Declare->buffer->data();
        Template::Declare->end_buffer_frame;
        return ( $content . $returned );
    } else {

        return $self->();
    }
}

1;
