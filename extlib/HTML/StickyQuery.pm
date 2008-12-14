package HTML::StickyQuery;
# $Id: StickyQuery.pm,v 1.10 2003/10/08 09:46:55 ikebe Exp $
use strict;
use base qw(HTML::Parser);
use URI;
use vars qw($VERSION);

$VERSION = '0.12';

sub new {
    my $class = shift;
    _croak("odd number of " . __PACKAGE__ . "->new arguments") if @_ % 2;
    my %args = @_;
    my $self = bless {
	keep_original => 1,
	abs => 0,
	regexp => undef,
    }, $class;
    foreach my $key(qw(keep_original abs regexp)) {
	$self->{$key} = $args{$key} if exists $args{$key};
    }
    # backward compat
    $self->{keep_original} = !$args{override} if $args{override};
    $self->SUPER::init;
    $self->boolean_attribute_value('__BOOLEAN__');
    $self;
}

sub sticky {
    my $self = shift;
    my %args = @_;
    if (ref $args{param} eq 'HASH') {
	$self->{param} = $args{param}
    }
    elsif ($args{param}->can("param")) {
	my %data = ();
	for my $key($args{param}->param) {
	    my @val = $args{param}->param($key);
	    $data{$key} = scalar(@val) > 1 ? \@val : $val[0];
	}
	$self->{param} = \%data;
    }

    if ($args{sticky_keys}) {
	my %sticky = map { $_ => 1 } @{$args{sticky_keys}};
	my %new;
	while (my($k, $v) = each %{$self->{param}}) {
	    $new{$k} = $v if $sticky{$k}
	}
	$self->{param} = \%new;
    }

    $self->{output} = "";
    if ($args{file}) {
	$self->parse_file($args{file});
    }
    elsif ($args{scalarref}) {
	$self->parse(${$args{scalarref}});
    }
    elsif ($args{arrayref}) {
	foreach my $line(@{$args{arrayref}}) {
	    $self->parse($line);
	}
    }
    return $self->{output};
}

sub output {
    my $self = shift;
    return $self->{output};
}

sub start {
    my ($self, $tagname, $attr, $attrseq, $orig) = @_;
    if ($tagname ne 'a') {
	$self->{output} .= $orig;
	return;
    }
    else {
	unless(exists $attr->{href}) {
	    $self->{output} .= $orig;
	    return;
	}
	my $u = URI->new($attr->{href});

	# skip absolute URI
	if (!$self->{abs} && $u->scheme) {
	    $self->{output} .= $orig;
	    return;
	}
	# when URI has other scheme (ie. mailto ftp ..)
	if(defined($u->scheme) && $u->scheme !~ m/^https?/) {
	    $self->{output} .= $orig;
	    return;
	}
	else {
	    if (!$self->{regexp} || $u->path =~ m/$self->{regexp}/) {
		if ($self->{keep_original}) {
		    my %original;
		    my @original = $u->query_form;
		    while (my ($key, $val) = splice(@original, 0, 2)) {
			if (exists $original{$key}) {
			    if (ref $original{$key} eq 'ARRAY') {
				push @{$original{$key}}, $val;
			    }
			    else {
				$original{$key} = [ $original{$key}, $val ];
			    }
			}
			else {
			    $original{$key} = $val;			    
			}
		    } 
		    my %merged = (%original, %{$self->{param}});
		    $u->query_form(%merged);
		}
		else {
		    $u->query_form(%{$self->{param}});
		}
		$self->{output} .= qq{<$tagname};
		# save attr order.
		foreach my $key(@$attrseq) {
		    if ($key eq "href"){
			$self->{output} .= sprintf(qq{ href="%s"},
						   $self->escapeHTML($u->as_string));
		    }
		    elsif ($attr->{$key} eq '__BOOLEAN__') {
			$self->{output} .= " $key";
		    }
		    else {
			$self->{output} .= sprintf(qq{ $key="%s"},
						   $self->escapeHTML($attr->{$key}));
		    }
		}
		$self->{output} .= '>';
		return;
	    }
	    $self->{output} .= $orig;
	}
    }
}

sub process {
    my($self, $text, $orig) = @_;
    $self->{output} .= $orig;
}

sub end {
    my ($self, $tagname, $orig) = @_;
    $self->{output} .= $orig;
}

sub text {
    my ($self, $orig) = @_;
    $self->{output} .= $orig;
}

sub comment {
    my ($self, $orig) = @_;
    $self->{output} .= qq/<!--$orig-->/;
}

sub declaration {
    my ($self, $orig) = @_;
    $self->{output} .= qq/<!$orig>/;
}

sub _croak {
    require Carp;
    Carp::croak(@_);
}

sub escapeHTML {
    my $self = shift;
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

1;

__END__

=head1 NAME

HTML::StickyQuery - add sticky QUERY_STRING 

=head1 SYNOPSIS

  use HTML::StickyQuery;

  # create an object
  my $s = HTML::StickyQuery->new(
       regexp => '\.cgi$',
       abs => 0,
       keep_original => 1,
  );

  print $s->sticky(
      file => 'foo.html',
      param => { SESSIONID => 'xxx' }
  );

 or

  my $q = CGI->new;
  print $s->sticky(
      file => 'foo.html',
      param => $q,
      sticky_keys => [qw(SESSIONID)]
  );


=head1 DESCRIPTION

this module is a sub class of L<HTML::Parser>.
parse HTML document and add QUERY_STRING to href attributes.
Handy for maintaining state without cookie or something, transparently.

if you want to use sticky CGI data via FORM.
it is better to use L<HTML::FillInForm>.

=head1 CONSTRUCTOR

=over 4

=item new(%option)

constructor of HTML::StickyQuery object. the options are below.

=over 5

=item abs

add QUERY_STRING to absolute URI or not. (default: 0)

=item override

this option is obsolete.
please use keep_original option.

=item keep_original

keep original QUERY_STRING or not. (default: 1)
when this option is false. all old QUERY_STRING is removed.

=item regexp

regular expression of affected URI. (default: I<none>)

=back

=back

=head1 METHODS

=over 4

=item sticky(%options)

parse HTML and add QUERY_STRING. return HTML document.
the options are below.

=over 5

=item file

specify the HTML file.

=item scalarref

specify the HTML document as scalarref.

=item arrayref

specify the HTML document as arrayref.

=item param

QUERY_STRING data. as hashref or object which implements I<param> method.
(eg. CGI, Apache::Request)

=item sticky_keys

specify sticky data keys as arrayref. any keys which are not in this list are ignored.
if not specified, all keys are kept.

=back

=back

=head1 EXAMPLES

=head2 KEEP SESSION ID

typical example of CGI application using session.

use L<Apache::Session>,L<HTML::Template> and L<HTML::StickyQuery>

template file:

 <html>
 <head>
 <title>Session Test</title>
 </head>
 <body>
 COUNT: <TMPL_VAR NAME="count"><br>
 <hr>
 <a href="session.cgi">countup</a><br>
 <hr>
 </body>
 </html>

session.cgi:

 #!perl
 
 use strict;
 use CGI;
 use HTML::Template;
 use HTML::StickyQuery;
 use Apache::Session::DB_File;
 
 my %session;
 my $cgi = CGI->new;
 
 # create session.
 my $id = $cgi->param('SESSIONID');
 tie %session,'Apache::Session::DB_File',$id,{
	 				      FileName => './session.db',
 					      LockDirectory => './lock'
 };

 $session{count} = $session{count} + 1;
 
 my $tmpl = HTML::Template->new(filename => './test.html');
 
 $tmpl->param(count => $session{count});
 
 my $output = $tmpl->output;
 
 # no COOKIE
 print $cgi->header;
 
 my $stq = HTML::StickyQuery->new;
 print $stq->sticky(
     scalarref => \$output,
     param => { SESSIONID => $session{_session_id} }
 );

=head2 KEEP SEARCH WORD IN HTML PAGING

template file (simplified):

  <A href="./search.cgi?pagenum=<TMPL_VAR name=nextpage>">Next 20 results</A>

search.cgi:

  #!perl
  use CGI;
  use HTML::StickyQuery;
  use HTML::Template;

  my $query = CGI->new;
  my $tmpl  = HTML::Template->new(filename => 'search.html');

  # do searching with $query and put results into $tmpl
  # ...

  # set next page offset
  $tmpl->param(nextpagee => $query->param('pagenum') + 1);

  my $output = $tmpl->output;
  my $sticky = HTML::StickyQuery->new(regexp => qr/search\.cgi$/);
  print $query->header, $sticky->sticky(
      scalarref => \$output,
      param => $qyery,
      sticky_keys => [qw(search)]
  );


=head1 AUTHOR

IKEBE Tomohiro E<lt>ikebe@edge.co.jpE<gt>

=head1 SEE ALSO

L<HTML::Parser> L<HTML::FillInForm>

=head1 CREDITS

Fixes,Bug Reports.

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright(C) 2002 IKEBE Tomohiro All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself. 

=cut

