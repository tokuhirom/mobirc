package HTTP::Engine::Role::RequestBuilder::Standard;
use Mouse::Role;

use Socket qw[AF_INET inet_aton];

with qw(HTTP::Engine::Role::RequestBuilder);
use CGI::Simple::Cookie ();

sub _build_cookies {
    my($self, $req) = @_;

    if (my $header = $req->header('Cookie')) {
        return { CGI::Simple::Cookie->parse($header) };
    } else {
        return {};
    }
}

sub _build_hostname {
    my ( $self, $req ) = @_;
    gethostbyaddr( inet_aton( $req->address ), AF_INET );
}

1;
