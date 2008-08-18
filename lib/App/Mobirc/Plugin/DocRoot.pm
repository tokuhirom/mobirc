package App::Mobirc::Plugin::DocRoot;
use strict;
use MooseX::Plaggerize::Plugin;
use App::Mobirc::Util;
use XML::LibXML;
use Encode;
use Params::Validate ':all';
use App::Mobirc::Validator;

has root => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook request_filter => sub {
    my ($self, $global_context, $req) = validate_hook('request_filter', @_);

    my $root = $self->root;
    $root =~ s!/$!!;

    my $path = $req->uri->path;
    $path =~ s!^$root!!;
    $req->uri->path($path);
};

hook response_filter => sub {
    my ($self, $global_context, $res) = validate_hook('response_filter', @_);

    if (my $loc = $res->header('Location')) {
        DEBUG "REWRITE REDIRECT : $loc";

        my $root = $self->root;
        $root =~ s!/$!!;
        $loc = "$root$loc";

        $res->header( Location => $loc );

        DEBUG "FINISHED: $loc";
    }
};

hook html_filter => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);

    DEBUG "FILTER DOCROOT";
    DEBUG "CONTENT IS UTF* : " . Encode::is_utf8($content);

    my $root = $self->root;
    $root =~ s!/$!!;

    my $doc = eval { XML::LibXML->new->parse_html_string($content) };
    if ($@) {
        warn "$content, orz.\n $@";
        return ($req, $content);
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

    return ($req, decode($doc->encoding || "UTF-8", $html));
};

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

