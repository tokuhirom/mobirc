package App::Mobirc::Plugin::StickyTime;
use strict;
use MooseX::Plaggerize::Plugin;
use App::Mobirc::Util;
use HTML::StickyQuery;

hook response_filter => sub {
    my ($self, $global_context, $c) = @_;

    if ($c->res->redirect) {
        my $uri  = URI->new($c->res->redirect);
        $uri->query_form( $uri->query_form, t => time() );
        return $c->res->redirect( $uri->as_string );
    }
};

hook html_filter => sub {
    my ($self, $global_context, $c, $content) = @_;

    my $sticky = HTML::StickyQuery->new();

    return (
        $c,
        $sticky->sticky(
            scalarref => \$content,
            param     => { t => time() },
        )
    );
};

1;
__END__

=encoding utf8

=head1 NAME

App::Mobirc::Plugin::HTMLFilter::StickyTime - f*cking au cache

=head1 DESCRIPTION

au phone cache very strongly like IE's Ajax.

this filer appends ?t=time() to `a' tag.

=head1 AUTHOR

tokuhirom

=head1 SEE ALSO

L<App::Mobirc>

