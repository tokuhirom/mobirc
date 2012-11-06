package App::Mobirc::Plugin::DocRoot;
use strict;
use warnings;
use App::Mobirc::Plugin;
use App::Mobirc::Util;
use Encode;
use Params::Validate ':all';
use App::Mobirc::Validator;
use HTML::TreeBuilder::XPath;

has root => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook env_filter => sub {
    my ($self, $global_context, $env) = @_;

    my $root = $self->root;
    $root =~ s!/$!!;

    $env->{PATH_INFO} =~ s!^$root!!;
    $env->{SCRIPT_NAME} = $root;
};

hook response_filter => sub {
    my ($self, $global_context, $res) = @_;

    if (my $loc = $res->header('Location')) {
        my $root = $self->root;
        $root =~ s!/$!!;
        $loc = $root . $loc if $loc !~ /^\Q$root\E/;
        return $res->header( Location => $loc );
    }
};

hook html_filter => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);

    DEBUG "FILTER DOCROOT";
    DEBUG "CONTENT IS UTF* : " . Encode::is_utf8($content);

    my $root = $self->root;
    $root =~ s!/$!!;

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse_content($content);
    for my $elem ($tree->findnodes('//a')) {
        if (my $href = $elem->attr('href')) {
            if ($href =~ m{^/}) {
                $elem->attr(href => $root . $href);
            }
        }
    }
    for my $elem ($tree->findnodes('//img')) {
        if (my $href = $elem->attr('src')) {
            if ($href =~ m{^/}) {
                $elem->attr(src => $root . $href);
            }
        }
    }
    for my $elem ($tree->findnodes('//form')) {
        if (my $uri = $elem->attr('action')) {
            if ($uri =~ m{^/}) {
                $elem->attr(action => $root . $uri);
            }
        }
    }
    for my $elem ($tree->findnodes('//link')) {
        if (my $uri = $elem->attr('href')) {
            if ($uri =~ m{^/}) {
                $elem->attr(href => $root . $uri);
            }
        }
    }
    for my $elem ($tree->findnodes('//script')) {
        if (my $uri = $elem->attr('src')) {
            if ($uri =~ m{^/}) {
                $elem->attr(src => $root . $elem->attr('src'));
            }
        }
    }

    my $html = $tree->as_HTML(q[<>&"'{}]);
    $tree = $tree->delete;

    return ($req, decode_utf8($html));
};

1;
__END__

=head1 NAME

App::Mobirc::Plugin::DocRoot - rewrite document root

=head1 SYNOPSIS

    # in your config.ini
    [DocRoot]
    root=/mobirc/

=head1 DESCRIPTION

rewrite path.

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<App::Mobirc>

