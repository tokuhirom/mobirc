package Plack::Middleware::ReverseProxy;

use strict;
use warnings;
use 5.008_001;
use parent qw(Plack::Middleware);
our $VERSION = '0.14';

sub call {
    my $self = shift;
    my $env = shift;

    # in apache2 httpd.conf (RequestHeader set X-Forwarded-HTTPS %{HTTPS}s)
    $env->{HTTPS} = $env->{'HTTP_X_FORWARDED_HTTPS'}
        if $env->{'HTTP_X_FORWARDED_HTTPS'};
    $env->{HTTPS} = 'ON'
        if $env->{'HTTP_X_FORWARDED_PROTO'} && $env->{'HTTP_X_FORWARDED_PROTO'} eq 'https';    # Pound
    $env->{'psgi.url_scheme'}  = 'https' if $env->{HTTPS} && uc $env->{HTTPS} eq 'ON';
    my $default_port = $env->{'psgi.url_scheme'} eq 'https' ? 443 : 80;


    # If we are running as a backend server, the user will always appear
    # as 127.0.0.1. Select the most recent upstream IP (last in the list)
    if ( $env->{'HTTP_X_FORWARDED_FOR'} ) {
        my ( $ip, ) = $env->{HTTP_X_FORWARDED_FOR} =~ /([^,\s]+)$/;
        $env->{REMOTE_ADDR} = $ip;
    }

    if ( $env->{HTTP_X_FORWARDED_HOST} ) {

        # in apache1 ServerName example.com:443
        if ( $env->{HTTP_X_FORWARDED_SERVER} ) {
            my ( $host, ) = $env->{HTTP_X_FORWARDED_SERVER} =~ /([^,\s]+)$/;
            if ( $host =~ /^(.+):(\d+)$/ ) {
#            $host = $1;
                $env->{SERVER_PORT} = $2;
                $env->{'psgi.url_scheme'}  = 'https' if $env->{SERVER_PORT} == 443;
            }
            $env->{HTTP_HOST} = $host;
        }

        my ( $host, ) = $env->{HTTP_X_FORWARDED_HOST} =~ /([^,\s]+)$/;
        if ( $host =~ /^(.+):(\d+)$/ ) {
#            $host = $1;
            $env->{SERVER_PORT} = $2;
        } elsif ( $env->{HTTP_X_FORWARDED_PORT} ) {
            # in apache2 httpd.conf (RequestHeader set X-Forwarded-Port 8443)
            $env->{SERVER_PORT} = $env->{HTTP_X_FORWARDED_PORT};
            $host .= ":$env->{SERVER_PORT}";
            $env->{'psgi.url_scheme'} = 'https'
                if $env->{SERVER_PORT} == 443;
        } else {
            $env->{SERVER_PORT} = $default_port;
        }
        $env->{HTTP_HOST} = $host;

    } elsif ( $env->{HTTP_HOST} ) {
        my $host = $env->{HTTP_HOST};
        if ($host =~ /^(.+):(\d+)$/ ) {
#            $env->{HTTP_HOST}   = $1;
            $env->{SERVER_PORT} = $2;
        } elsif ($host =~ /^(.+)$/ ) {
            $env->{HTTP_HOST}   = $1;
            $env->{SERVER_PORT} = $default_port;
        }
    }

    $self->app->($env);
}

1;

__END__

=head1 NAME

Plack::Middleware::ReverseProxy - Supports app to run as a reverse proxy backend

=head1 SYNOPSIS

  builder {
      enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 
          "Plack::Middleware::ReverseProxy";
      $app;
  };

=head1 DESCRIPTION

Plack::Middleware::ReverseProxy resets some HTTP headers, which changed by
reverse-proxy. You can specify the reverse proxy address and stop fake requests
using 'enable_if' directive in your app.psgi.

=head1 LICENSE

This software is licensed under the same terms as Perl itself.

=head1 AUTHOR

This module is originally written by Kazuhiro Osawa as L<HTTP::Engine::Middleware::ReverseProxy> for L<HTTP::Engine>.

Nobuo Danjou

Masahiro Nagano

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<HTTP::Engine::Middleware::ReverseProxy> 

L<Plack>

L<Plack::Middleware>

L<Plack::Middleware::Conditional>

=cut
