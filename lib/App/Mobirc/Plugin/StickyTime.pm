package App::Mobirc::Plugin::StickyTime;
use strict;
use MouseX::Plaggerize::Plugin;
use App::Mobirc::Util;
use HTML::StickyQuery;
use App::Mobirc::Validator;

hook response_filter => sub {
    my ($self, $global_context, $res) = validate_hook('response_filter', @_);

    if (my $loc = $res->header('Location')) {
        my $joinner = ($loc =~ /\?/) ? '&' : '?';
        $loc = $loc . $joinner . "t=@{[ time() ]}";
        return $res->header( Location => $loc );
    }
};

hook html_filter => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);

    my $sticky = HTML::StickyQuery->new();

    return (
        $req,
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

App::Mobirc::Plugin::StickyTime - f*cking au cache

=head1 DESCRIPTION

au phone cache very strongly like IE's Ajax.

this filer appends ?t=time() to `a' tag.

this module load to core automatically.

=head1 AUTHOR

tokuhirom

=head1 SEE ALSO

L<App::Mobirc>

