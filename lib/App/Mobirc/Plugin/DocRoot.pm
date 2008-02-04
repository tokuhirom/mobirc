package App::Mobirc::Plugin::DocRoot;
use strict;
use warnings;
use App::Mobirc::Util;
use XML::LibXML;

sub register {
    my ($class, $global_context, $conf) = @_;

    DEBUG "Rewrite Document Root";

    $global_context->register_hook(
        'html_filter' => sub { _html_filter_docroot($_[0], $_[1], $conf) },
    );
}

sub _html_filter_docroot {
    my ($c, $content, $conf) = @_;

    my $root = $conf->{root};
    $root =~ s!/$!!;

    my $doc = XML::LibXML->new->parse_html_string($content);
    for my $elem ($doc->findnodes('//a')) {
        if (my $href = $elem->getAttribute('href')) {
            if ($href =~ m{^/}) {
                $elem->setAttribute(href => $root . $href);
            }
        }
    }
    for my $elem ($doc->findnodes('//form')) {
        if (my $uri = $elem->getAttribute('action')) {
            if ($uri =~ m{^/}) {
                $elem->setAttribute(action => $root . $uri);
            }
        }
    }
    for my $elem ($doc->findnodes('//link')) {
        $elem->setAttribute(href => $root . $elem->getAttribute('href'));
    }
    for my $elem ($doc->findnodes('//script')) {
        $elem->setAttribute(src => $root . $elem->getAttribute('src'));
    }

    U $doc->toStringHTML;
}

1;
__END__

=head1 NAME

App::Mobirc::Plugin::DocRoot - rewrite document root

=head1 SYNOPSIS

    - module: App::Mobirc::Plugin::DocRoot
      config:
        root: /foo/

=head1 DESCRIPTION

rewrite path.

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<App::Mobirc>

