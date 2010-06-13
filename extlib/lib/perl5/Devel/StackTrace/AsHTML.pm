package Devel::StackTrace::AsHTML;

use strict;
use 5.008_001;
our $VERSION = '0.09';

use Data::Dumper;
use Devel::StackTrace;
use Scalar::Util;

no warnings 'qw';
my %enc = qw( & &amp; > &gt; < &lt; " &quot; ' &#39; );

# NOTE: because we don't know which encoding $str is in, or even if
# $str is a wide character (decoded strings), we just leave the low
# bits, including latin-1 range and encode everything higher as HTML
# entities. I know this is NOT always correct, but should mostly work
# in case $str is encoded in utf-8 bytes or wide chars. This is a
# necessary workaround since we're rendering someone else's code which
# we can't enforce string encodings.

sub encode_html {
    my $str = shift;
    $str =~ s/([^\x00-\x21\x23-\x25\x28-\x3b\x3d\x3f-\xff])/$enc{$1} || '&#' . ord($1) . ';' /ge;
    utf8::downgrade($str);
    $str;
}

sub Devel::StackTrace::as_html {
    __PACKAGE__->render(@_);
}

sub render {
    my $class = shift;
    my $trace = shift;
    my %opt   = @_;

    my $msg = encode_html($trace->frame(1)->args);
    my $out = qq{<!doctype html><head><title>Error: ${msg}</title>};

    $opt{style} ||= \<<STYLE;
a.toggle { color: #444 }
body { margin: 0; padding: 0; background: #fff; color: #000; }
h1 { margin: 0 0 .5em; padding: .25em .5em .1em 1.5em; border-bottom: thick solid #002; background: #444; color: #eee; font-size: x-large; }
pre.message { margin: .5em 1em; }
li.frame { font-size: small; margin-top: 3em }
li.frame:nth-child(1) { margin-top: 0 }
pre.context { border: 1px solid #aaa; padding: 0.2em 0; background: #fff; color: #444; font-size: medium; }
pre .match { color: #000;background-color: #f99; font-weight: bold }
pre.vardump { margin:0 }
pre code strong { color: #000; background: #f88; }

table.lexicals, table.arguments { border-collapse: collapse }
table.lexicals td, table.arguments td { border: 1px solid #000; margin: 0; padding: .3em }
table.lexicals tr:nth-child(2n) { background: #DDDDFF }
table.arguments tr:nth-child(2n) { background: #DDFFDD }
.lexicals, .arguments { display: none }
.variable, .value { font-family: monospace; white-space: pre }
td.variable { vertical-align: top }
STYLE

    if (ref $opt{style}) {
        $out .= qq(<style type="text/css">${$opt{style}}</style>);
    } else {
        $out .= qq(<link rel="stylesheet" type="text/css" href=") . encode_html($opt{style}) . q(" />);
    }

    $out .= <<HEAD;
<script language="JavaScript" type="text/javascript">
function toggleThing(ref, type, hideMsg, showMsg) {
 var css = document.getElementById(type+'-'+ref).style;
 css.display = css.display == 'block' ? 'none' : 'block';

 var hyperlink = document.getElementById('toggle-'+ref);
 hyperlink.textContent = css.display == 'block' ? hideMsg : showMsg;
}

function toggleArguments(ref) {
 toggleThing(ref, 'arguments', 'Hide function arguments', 'Show function arguments');
}

function toggleLexicals(ref) {
 toggleThing(ref, 'lexicals', 'Hide lexical variables', 'Show lexical variables');
}
</script>
</head>
<body>
<h1>Error trace</h1><pre class="message">$msg</pre><ol>
HEAD

    $trace->next_frame; # ignore the head
    my $i = 0;
    while (my $frame = $trace->next_frame) {
        $i++;
        $out .= join(
            '',
            '<li class="frame">',
            $frame->subroutine ? encode_html("in " . $frame->subroutine) : '',
            ' at ',
            $frame->filename ? encode_html($frame->filename) : '',
            ' line ',
            $frame->line,
            q(<pre class="context"><code>),
            _build_context($frame) || '',
            q(</code></pre>),
            _build_arguments($i, [$frame->args]),
            $frame->can('lexicals') ? _build_lexicals($i, $frame->lexicals) : '',
            q(</li>),
        );
    }
    $out .= qq{</ol>};
    $out .= "</body></html>";

    $out;
}

my $dumper = sub {
    my $value = shift;
    $value = $$value if ref $value eq 'SCALAR' or ref $value eq 'REF';
    my $d = Data::Dumper->new([ $value ]);
    $d->Indent(1)->Terse(1)->Deparse(1);
    chomp(my $dump = $d->Dump);
    $dump;
};

sub _build_arguments {
    my($id, $args) = @_;
    my $ref = "arg-$id";

    return '' unless @$args;

    my $html = qq(<p><a class="toggle" id="toggle-$ref" href="javascript:toggleArguments('$ref')">Show function arguments</a></p><table class="arguments" id="arguments-$ref">);

    # Don't use while each since Dumper confuses that
    for my $idx (0 .. @$args - 1) {
        my $value = $args->[$idx];
        my $dump = $dumper->($value);
        $html .= qq{<tr>};
        $html .= qq{<td class="variable">\$_[$idx]</td>};
        $html .= qq{<td class="value">} . encode_html($dump) . qq{</td>};
        $html .= qq{</tr>};
    }
    $html .= qq(</table>);

    return $html;
}

sub _build_lexicals {
    my($id, $lexicals) = @_;
    my $ref = "lex-$id";

    return '' unless keys %$lexicals;

    my $html = qq(<p><a class="toggle" id="toggle-$ref" href="javascript:toggleLexicals('$ref')">Show lexical variables</a></p><table class="lexicals" id="lexicals-$ref">);

    # Don't use while each since Dumper confuses that
    for my $var (sort keys %$lexicals) {
        my $value = $lexicals->{$var};
        my $dump = $dumper->($value);
        $dump =~ s/^\{(.*)\}$/($1)/s if $var =~ /^\%/;
        $dump =~ s/^\[(.*)\]$/($1)/s if $var =~ /^\@/;
        $html .= qq{<tr>};
        $html .= qq{<td class="variable">} . encode_html($var)  . qq{</td>};
        $html .= qq{<td class="value">}    . encode_html($dump) . qq{</td>};
        $html .= qq{</tr>};
    }
    $html .= qq(</table>);

    return $html;
}

sub _build_context {
    my $frame = shift;
    my $file    = $frame->filename;
    my $linenum = $frame->line;
    my $code;
    if (-f $file) {
        my $start = $linenum - 3;
        my $end   = $linenum + 3;
        $start = $start < 1 ? 1 : $start;
        open my $fh, '<', $file
            or die "cannot open $file:$!";
        my $cur_line = 0;
        while (my $line = <$fh>) {
            ++$cur_line;
            last if $cur_line > $end;
            next if $cur_line < $start;
            $line =~ s|\t|        |g;
            my @tag = $cur_line == $linenum
                ? (q{<strong class="match">}, '</strong>')
                    : ('', '');
            $code .= sprintf(
                '%s%5d: %s%s', $tag[0], $cur_line, encode_html($line),
                $tag[1],
            );
        }
        close $file;
    }
    return $code;
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Devel::StackTrace::AsHTML - Displays stack trace in HTML

=head1 SYNOPSIS

  use Devel::StackTrace::AsHTML;

  my $trace = Devel::StackTrace->new;
  my $html  = $trace->as_html;

=head1 DESCRIPTION

Devel::StackTrace::AsHTML adds C<as_html> method to L<Devel::StackTrace> which
displays the stack trace in beautiful HTML, with code snippet context and
function parameters. If you call it on an instance of
L<Devel::StackTrace::WithLexicals>, you even get to see the lexical variables
of each stack frame.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Shawn M Moore

HTML generation code is ripped off from L<CGI::ExceptionManager> written by Tokuhiro Matsuno and Kazuho Oku.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Devel::StackTrace> L<Devel::StackTrace::WithLexicals> L<CGI::ExceptionManager>

=cut
