package HTTP::Engine::Middleware::DoCoMoGUID;
use HTTP::Engine::Middleware;
use Scalar::Util ();
use HTML::StickyQuery;

after_handle {
    my ( $c, $self, $req, $res ) = @_;

    if (   $res->status == 200
        && $res->content_type =~ /html/
        && not Scalar::Util::blessed $res->body
        && $res->body )
    {
        my $body = $res->body;
        $res->body(
            sub {
                my $guid = HTML::StickyQuery->new( 'abs' => 1, );
                $guid->sticky(
                    scalarref => \$body,
                    param     => { guid => 'ON' },
                );
                }
                ->()
        );
    }

    $res;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::DoCoMoGUID - append guid=ON on each anchor tag

=head1 SYNOPSIS

This module appends ?guid=ON on each anchor tag.
This feature is needed by Japanese mobile web site developers.

=head1 AUTHORS

tokuhirom

yappo

=head1 SEE ALSO

L<HTML::StickyQuery>

=cut
