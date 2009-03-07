package HTTP::Engine::Middleware::ReverseProxy;
use HTTP::Engine::Middleware;

before_handle {
    my ( $c, $self, $req ) = @_;
    my $env = $req->_connection->{env} || {};

    # in apache httpd.conf (RequestHeader set X-Forwarded-HTTPS %{HTTPS}s)
    $env->{HTTPS} = $req->headers->{'x-forwarded-https'}
        if $req->headers->{'x-forwarded-https'};
    $env->{HTTPS} = 'ON' if $req->headers->{'x-forwarded-proto'};    # Pound
    $req->secure(1) if $env->{HTTPS} && uc $env->{HTTPS} eq 'ON';
    my $default_port = $req->secure ? 443 : 80;

    # If we are running as a backend server, the user will always appear
    # as 127.0.0.1. Select the most recent upstream IP (last in the list)
    if ( $req->headers->{'x-forwarded-for'} ) {
        my ( $ip, ) = $req->headers->{'x-forwarded-for'} =~ /([^,\s]+)$/;
        $req->address($ip);
    }

    if ( $req->headers->{'x-forwarded-host'} ) {
        my $host = $req->headers->{'x-forwarded-host'};
        if ( $host =~ /^(.+):(\d+)$/ ) {
            $host = $1;
            $env->{SERVER_PORT} = $2;
        } elsif ( $req->headers->{'x-forwarded-port'} ) {
            # in apache httpd.conf (RequestHeader set X-Forwarded-Port 8443)
            $env->{SERVER_PORT} = $req->headers->{'x-forwarded-port'};
        } else {
            $env->{SERVER_PORT} = $default_port;
        }
        $env->{HTTP_HOST} = $host;

        $req->headers->header( 'Host' => $env->{HTTP_HOST} );
    } elsif ($req->headers->{'host'}) {
        my $host = $req->headers->{'host'};
        if ($host =~ /^(.+):(\d+)$/ ) {
            $env->{HTTP_HOST}   = $1;
            $env->{SERVER_PORT} = $2;
        } elsif ($host =~ /^(.+)$/ ) {
            $env->{HTTP_HOST}   = $1;
            $env->{SERVER_PORT} = $default_port;
        }
    } else {
        $env->{HTTP_HOST}   = $req->uri->host;
        $env->{SERVER_PORT} = $req->uri->port || $default_port;
    }
    $req->_connection->{env} = $env;

    for my $attr (qw/uri base/) {
        my $scheme = $req->secure ? 'https' : 'http';
        my $host = $env->{HTTP_HOST} || $env->{SERVER_NAME};
        my $port = $env->{SERVER_PORT} || undef;
        # my $path_info = $env->{PATH_INFO} || '/';

        $req->$attr->scheme($scheme);
        $req->$attr->host($host);
        if (($port || '') eq $default_port) {
            $req->$attr->port(undef);
        } else {
            $req->$attr->port($port);
        }

        # $req->$attr->path($path_info);
        # $req->$attr( $req->$attr->canonical );
    }
    $req;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::ReverseProxy - reverse-proxy support

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(qw/ HTTP::Engine::Middleware::ReverseProxy /);
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 DESCRIPTION

This module resets some HTTP headers, which changed by reverse-proxy.

=head1 AUTHORS

yappo

=cut
