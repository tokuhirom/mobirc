package HTTP::Engine::Role::RequestBuilder::Standard;
use Any::Moose '::Role';

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

# for win32 hacks
BEGIN {
    if ($^O eq 'MSWin32') {
        no warnings 'redefine';
        *_build_hostname = sub {
            my ( $self, $req ) = @_;
            my $address = $req->address;
            return 'localhost' if $address eq '127.0.0.1';
            return gethostbyaddr( inet_aton( $address ), AF_INET );
        };
    }
}

1;
