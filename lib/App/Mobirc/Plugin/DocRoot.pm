package App::Mobirc::Plugin::DocRoot;
use strict;
use warnings;
use App::Mobirc::Util;
use XML::LibXML;
use Encode;

sub register {
    my ($class, $global_context, $conf) = @_;

    DEBUG "Rewrite Document Root";

    $global_context->register_hook(
        request_filter => sub { _request_filter($conf, @_) },
    );
    $global_context->register_hook(
        response_filter => sub { _response_filter($conf, @_) },
    );
    $global_context->register_hook(
        'html_filter' => sub { _html_filter_docroot($_[0], $_[1], $conf) },
    );
}

sub _request_filter {
    my ($conf, $c) = @_;

    my $root = $conf->{root};
    $root =~ s!/$!!;

    my $path = $c->req->uri->path;
    DEBUG "BEFORE : " . $c->req->uri;
    $path =~ s!^$root!!;
    $c->req->uri->path($path);
    DEBUG "AFTER  : " . $c->req->uri;
}

sub _response_filter {
    my ($conf, $c) = @_;

    if ($c->res->redirect) {
        DEBUG "REWRITE REDIRECT : " . $c->res->redirect;

        my $root = $conf->{root};
        $root =~ s!/$!!;
        $c->res->redirect( $root . $c->res->redirect );

        DEBUG "FINISHED: " . $c->res->redirect;
    }
}

sub _html_filter_docroot {
    my ($c, $content, $conf) = @_;

    DEBUG "FILTER DOCROOT";
    DEBUG "CONTENT IS UTF* : " . Encode::is_utf8($content);

    my $root = $conf->{root};
    $root =~ s!/$!!;

    my $doc = eval { XML::LibXML->new->parse_html_string($content) };
    if ($@) {
        warn "$content, orz.\n $@";
        return $content;
    }
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
        if ($elem->hasAttribute('src')) {
            $elem->setAttribute(src => $root . $elem->getAttribute('src'));
        }
    }

    my $html = $doc->toStringHTML;
    $html =~ s{<!DOCTYPE[^>]*>\s*}{};

    decode($doc->encoding || "UTF-8", $html);
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

