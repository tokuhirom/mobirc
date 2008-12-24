package HTML::Selector::XPath;

use strict;
our $VERSION = '0.03';

require Exporter;
our @EXPORT_OK = qw(selector_to_xpath);
*import = \&Exporter::import;

use Carp;

sub selector_to_xpath {
    __PACKAGE__->new(shift)->to_xpath;
}

my $reg = {
    # tag name/id/class
    element => qr/^([#.]?)([a-z0-9\\*_-]*)((\|)([a-z0-9\\*_-]*))?/i,
    # attribute presence
    attr1   => qr/^\[([^\]]*)\]/,
    # attribute value match
    attr2   => qr/^\[\s*([^~\|=\s]+)\s*([~\|]?=)\s*"([^"]+)"\s*\]/i,
    attrN   => qr/^:not\((.*?)\)/i,
    pseudo  => qr/^:([()a-z0-9_-]+)/i,
    # adjacency/direct descendance
    combinator => qr/^(\s*[>+\s])/i,
    # rule separator
    comma => qr/^\s*,/i,
};


sub new {
    my($class, $exp) = @_;
    bless { expression => $exp }, $class;
}

sub selector {
    my $self = shift;
    $self->{expression} = shift if @_;
    $self->{expression};
}

sub to_xpath {
    my $self = shift;
    my $rule = $self->{expression} or return;

    my $index = 1;
    my @parts = ("//", "*");
    my $last_rule = '';
    my @next_parts;

    # Loop through each "unit" of the rule
    while (length $rule && $rule ne $last_rule) {
        $last_rule = $rule;

        $rule =~ s/^\s*|\s*$//g;
        last unless length $rule;

        # Match elements
        if ($rule =~ s/$reg->{element}//) {

            # to add *[1]/self:: for follow-sibling
            if (@next_parts) {
                push @parts, @next_parts, (pop @parts);
                $index += @next_parts;
                @next_parts = ();
            }

            if ($1 eq '#') { # ID
                push @parts, "[\@id='$2']";
            } elsif ($1 eq '.') { # class
                push @parts, "[contains(concat(' ', \@class, ' '), ' $2 ')]";
            } else {
                $parts[$index] = $5 || $2;
            }
        }

        # Match attribute selectors
        if ($rule =~ s/$reg->{attr2}//) {
            # negation (e.g. [input!="text"]) isn't implemented in CSS, but include it anyway:
            if ($2 eq '!=') {
                push @parts, "[\@$1!='$3]";
            } elsif ($2 eq '~=') { # substring attribute match
                push @parts, "[contains(concat(' ', \@$1, ' '), ' $3 ')]";
            } elsif ($2 eq '|=') {
                push @parts, "[\@$1='$3' or starts-with(\@$1, '$3-')]";
            } else { # exact match
                push @parts, "[\@$1='$3']";
            }
        } elsif ($rule =~ s/$reg->{attr1}//) {
            push @parts, "[\@$1]";
        }

        # Match negation
        if ($rule =~ s/$reg->{attrN}//) {
            my $sub_rule = $1;
            if ($sub_rule =~ s/$reg->{attr2}//) {
                if ($2 eq '=') {
                    push @parts, "[\@$1!='$3']";
                } elsif ($2 eq '~=') {
                    push @parts, "[not(contains(concat(' ', \@$1, ' '), ' $3 '))]";
                } elsif ($2 eq '|=') {
                    push @parts, "[not(\@$1='$3' or starts-with(\@$1, '$3-'))]";
                }
            } elsif ($sub_rule =~ s/$reg->{attr1}//) {
                push @parts, "[not(\@$1)]";
            } else {
                Carp::croak "Can't translate '$sub_rule' inside :not()";
            }
        }

        # Ignore pseudoclasses/pseudoelements
        while ($rule =~ s/$reg->{pseudo}//) {
            if ( $1 eq 'first-child') {
                $parts[$#parts] = '*[1]/self::' . $parts[$#parts];
            } elsif ($1 =~ /^lang\(([\w\-]+)\)$/) {
                push @parts, "[\@xml:lang='$1' or starts-with(\@xml:lang, '$1-')]";
            } elsif ($1 =~ /^nth-child\((\d+)\)$/) {
                push @parts, "[count(preceding-sibling::*) = @{[ $1 - 1 ]}]";
            } else {
                Carp::croak "Can't translate '$1' pseudo-class";
            }
        }

        # Match combinators (> and +)
        if ($rule =~ s/$reg->{combinator}//) {
            my $match = $1;
            if ($match =~ />/) {
                push @parts, "/";
            } elsif ($match =~ /\+/) {
                push @parts, "/following-sibling::";
                @next_parts = ('*[1]/self::');
            } else {
                push @parts, "//";
            }

            # new context
            $index = @parts;
            push @parts, "*";
        }

        # Match commas
        if ($rule =~ s/$reg->{comma}//) {
            push @parts, " | ", "//", "*"; # ending one rule and beginning another
            $index = @parts - 1;
        }
    }

    return join '', @parts;
}

1;
__END__

=head1 NAME

HTML::Selector::XPath - CSS Selector to XPath compiler

=head1 SYNOPSIS

  use HTML::Selector::XPath;

  my $selector = HTML::Selector::XPath->new("li#main");
  $selector->to_xpath; # //li[@id='main']

  # functional interface
  use HTML::Selector::Xpath 'selector_to_xpath';
  my $xpath = selector_to_xpath('div.foo');

=head1 DESCRIPTION

HTML::Selector::XPath is a utility function to compile CSS2 selector
to the equivalent XPath expression.

=head1 CAVEATS

=head2 CSS SELECTOR VALIDATION

This module doesn't validate whether the original CSS Selector
expression is valid. For example,

  div.123foo

is an invalid CSS selector (class names should not begin with
numbers), but this module ignores that and tries to generate
an equivalent XPath expression anyway.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Most of the code is based on Joe Hewitt's getElementsBySelector.js on
L<http://www.joehewitt.com/blog/2006-03-20.php> and Andrew Dupont's
patch to Prototype.js on L<http://dev.rubyonrails.org/ticket/5171>,
but slightly modified using Aristotle Pegaltzis' CSS to XPath
translation table per L<http://plasmasturm.org/log/444/>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://www.w3.org/TR/REC-CSS2/selector.html>
L<http://use.perl.org/~miyagawa/journal/31090>

=cut
