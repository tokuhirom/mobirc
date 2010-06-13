package HTML::TreeBuilder::LibXML;
use strict;
use warnings;
our $VERSION = '0.11';
use Carp ();
use base 'HTML::TreeBuilder::LibXML::Node';
use XML::LibXML;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub new_from_content {
    my $class = shift;
    my $self  = $class->new;
    for my $content (@_) {
        $self->parse($content);
    }
    $self->eof;

    return $self;
}

sub new_from_file {
    my $class = shift;
    my $self  = $class->new;
    $self->parse_file(@_);
    return $self;
}

my $PARSER;
sub _parser {
    unless ($PARSER) {
        $PARSER = XML::LibXML->new();
        $PARSER->recover(1);
        $PARSER->recover_silently(1);
        $PARSER->keep_blanks(0);
        $PARSER->expand_entities(1);
        $PARSER->no_network(1);
    }
    $PARSER;
}

sub parse {
    my ($self, $html) = @_;
    $self->{_content} .= $html;
}

sub parse_file {
    my $self = shift;
    my $doc  = $self->_parser->parse_html_file(@_);
    $self->{node} = $self->_documentElement($doc);
}

sub eof {
    my ($self, ) = @_;
    $self->{_content} = ' ' if defined $self->{_content} && $self->{_content} eq ''; # HACK
    my $doc = $self->_parser->parse_html_string($self->{_content});
    $self->{node} = $self->_documentElement($doc);
}

sub _documentElement {
    my($self, $doc) = @_;
    return $doc->documentElement || do {
        my $elem = $doc->createElement("html");
        $elem->appendChild($doc->createElement("body"));
        $elem;
    };
}

sub replace_original {
    require HTML::TreeBuilder::XPath;

    my $orig = HTML::TreeBuilder::XPath->can('new');

    no warnings 'redefine';
    *HTML::TreeBuilder::XPath::new = sub {
        HTML::TreeBuilder::LibXML->new();
    };

    if (defined wantarray) {
        return HTML::TreeBuilder::LibXML::Destructor->new(
            sub { *HTML::TreeBuilder::XPath::new = $orig } );
    }
    return;
}

package # hide from cpan
    HTML::TreeBuilder::LibXML::Destructor;

sub new {
    my ( $class, $callback ) = @_;
    bless { cb => $callback }, $class;
}

sub DESTROY {
    my $self = shift;
    $self->{cb}->();
}

1;
__END__

=head1 NAME

HTML::TreeBuilder::LibXML - HTML::TreeBuilder and XPath compatible interface with libxml

=head1 SYNOPSIS

    use HTML::TreeBuilder::LibXML;

    my $tree = HTML::TreeBuilder::LibXML->new;
    $tree->parse($html);
    $tree->eof;

    # $tree and $node compatible to HTML::Element
    my @nodes = $tree->findvalue($xpath);
    for my $node (@nodes) {
        print $node->tag;
        my %attr = $node->all_external_attr;
    }

    HTML::TreeBuilder::LibXML->replace_original(); # replace HTML::TreeBuilder::XPath->new

=head1 DESCRIPTION

HTML::TreeBuilder::XPath is libxml based compatible interface to
HTML::TreeBuilder, which could be slow for a large document.

HTML::TreeBuilder::LibXML is drop-in-replacement for HTML::TreeBuilder::XPath.

This module doesn't implement all of HTML::TreeBuilder and
HTML::Element APIs, but eough methods are defined so modules like
Web::Scraper work.

=head1 BENCHMARK

This is a benchmark result by tools/benchmark.pl

        Web::Scraper: 0.26
        HTML::TreeBuilder::XPath: 0.09
        HTML::TreeBuilder::LibXML: 0.01_01

                     Rate  no_libxml use_libxml
        no_libxml  5.45/s         --       -94%
        use_libxml 94.3/s      1632%         --

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom  slkjfd gmail.comE<gt>

Tatsuhiko Miyagawa E<lt>miyagawa@cpan.orgE<gt>

Masahiro Chiba

=head1 THANKS TO

woremacx++
http://d.hatena.ne.jp/woremacx/20080202/1201927162

id:dailyflower

=head1 SEE ALSO

L<HTML::TreeBuilder>, L<HTML::TreeBuilder::XPath>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
