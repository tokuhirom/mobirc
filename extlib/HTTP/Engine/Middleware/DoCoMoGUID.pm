package HTTP::Engine::Middleware::DoCoMoGUID;
use HTTP::Engine::Middleware;
use Scalar::Util qw/blessed/;
use HTML::StickyQuery;

after_handle {
    my ( $c, $self, $req, $res ) = @_;

    if (   $res->status == 200
        && $res->content_type =~ /html/
        && not blessed $res->body
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

HTTP::Engine::Middleware::DebugScreen - documentation is TODO

=head1 SEE ALSO

L<HTML::StickyQuery>

=cut
