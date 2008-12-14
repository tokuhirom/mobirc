package HTML::StickyQuery::DoCoMoGUID;

use strict;
use warnings;
our $VERSION = '0.01';

use HTML::StickyQuery;

sub new {
    my $class = shift;
    bless {
        sticky => HTML::StickyQuery->new( regexp => qr/./ ),
    }, $class;
}

sub sticky {
    my($self, %args) = @_;
    $args{param} ||= {};
    $args{param}->{guid} = 'ON' unless $args{disable_guid};

    local $self->{sticky}->{use_xhtml} = exists $args{xhtml} ? $args{xhtml} : 1;

    local *_start = *HTML::StickyQuery::start;
    local *HTML::StickyQuery::start = *start;
    $self->{sticky}->sticky( %args );
}

# sticky for FORM tag. original code is HTML::StickyQuery
sub start {
    my($self, $tagname, $attr, $attrseq, $orig) = @_;

    if ($tagname ne 'form') {
        # goto original code
        goto &_start;
    }

    unless(exists $attr->{action}) {
        $self->{output} .= $orig;
        return;
    }
    my $u = URI->new($attr->{action});

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

    if (!$self->{regexp} || $u->path =~ m/$self->{regexp}/) {
        # get method
        unless (($attr->{method} || '') =~ /^post$/i) {
            $self->{output} .= $orig;
            _sticky_input($self);
            return;
        }

        # post method
        if ($self->{keep_original}) {
            my %original;
            my @original = $u->query_form;
            while (my ($key, $val) = splice(@original, 0, 2)) {
                if (exists $original{$key}) {
                    if (ref $original{$key} eq 'ARRAY') {
                        push @{ $original{$key} }, $val;
                    } else {
                        $original{$key} = [ $original{$key}, $val ];
                    }
                } else {
                    $original{$key} = $val;
                }
            }
            $u->query_form( %original, (exists $self->{param}->{guid} ? (guid => $self->{param}->{guid}) : ()) );
        } else {
            $u->query_form(%{$self->{param}});
        }

        $self->{output} .= "<$tagname";
        # save attr order.
        for my $key (@{ $attrseq }) {
            if ($key eq 'action'){
                $self->{output} .= sprintf ' action="%s"', $self->escapeHTML($u->as_string);
            } elsif ($attr->{$key} eq '__BOOLEAN__') {
                $self->{output} .= " $key";
            } else {
                $self->{output} .= sprintf qq{ $key="%s"}, $self->escapeHTML($attr->{$key});
            }
        }
        $self->{output} .= '>';
        # add some params
        _sticky_input($self, 1);
        return;
    }

    $self->{output} .= $orig;
}

sub _sticky_input {
    my($self, $ignore_guid) = @_;
    while (my($key, $value) = each %{ $self->{param} }) {
        next if $ignore_guid && $key eq 'guid';
        $self->{output} .= sprintf '<input type="hidden" name="%s" value="%s"%s>',
                               $key, $value, ($self->{use_xhtml} ? ' /' : '');
    }
}

1;
__END__

=encoding utf8

=head1 NAME

HTML::StickyQuery::DoCoMoGUID - add guid query for DoCoMo imode

=head1 SYNOPSIS

  use HTML::StickyQuery::DoCoMoGUID;

  my $guid = HTML::StickyQuery::DoCoMoGUID->new;
  print $guid->sticky( scalarref => \$html );

add sessionid

  my $guid = HTML::StickyQuery::DoCoMoGUID->new;
  print $guid->sticky(
      scalarref => \$html,
      param     => { sessionid => 'SID' },
  );

guid=ON を出さない

  my $guid = HTML::StickyQuery::DoCoMoGUID->new;
  print $guid->sticky(
      scalarref    => \$html,
      param        => { sessionid => 'SID' },
      disable_guid => 1,
  );

FORM タグの時の INPUT タグを XHTML じゃ無くする

  my $guid = HTML::StickyQuery::DoCoMoGUID->new;
  print $guid->sticky(
      scalarref    => \$html,
      param        => { sessionid => 'SID' },
      disable_guid => 1,
      xhtml        => 0,
  );


=head1 DESCRIPTION

主に HTML::StickyQuery を使って DoCoMo用の guid=ON をつけるフィルタリングをするよ。
FORM タグがある場合には、 get method の時には input タグを追加して、 post method の時には action の中に guid=ON を追加します。

sticky method への引数に param => { key => value } を追加すると HTML::StickyQuery へそのまま処理が引き継がれるよ。
ただし、 FORM タグの場合は <input type="hidden" name="key" value="value" /> のような HTML が出力されます。

どんな感じでフィルタリングされるかは t ディレクトリの中のテストコードを参考にしてくださいね。

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 SEE ALSO

L<HTML::StickyQuery>, L<http://www.nttdocomo.co.jp/service/imode/make/content/ip/index.html#imodeid>

=head1 REPOSITORY

  svn co http://svn.coderepos.org/share/lang/perl/HTML-StickyQuery-DoCoMoGUID/trunk HTML-StickyQuery-DoCoMoGUID

HTML::StickyQuery::DoCoMoGUID is Subversion repository is hosted at L<http://coderepos.org/share/>.
patches and collaborators are welcome.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
