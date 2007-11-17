package Mobirc::Plugin::Authorizer::Cookie;
use strict;
use warnings;
use Mobirc::Util;
use Carp;
use CGI::Cookie;
use Digest::MD5 ();

our $SALT = 'CSS Nite';

sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        'authorize' => sub { my $c = shift;  _authorize($c, $conf) },
    );
    $global_context->register_hook(
        'response_filter' => sub { my ($c, $res) = @_;  _set_cookie($c, $res, $conf) },
    );
}

# comfort
sub _calc_digest {
    my ($password, ) = @_;

    return Digest::MD5::md5_hex( "$password,$SALT" );
}

sub _authorize {
    my ( $c, $conf ) = @_;

    my $cookie_str = $c->{req}->header('Cookie');
    unless ($cookie_str) {
        DEBUG "cookie header is empty";
        return false;
    }

    my %cookie = CGI::Cookie->parse($cookie_str);
    if ( $cookie{mobirc_key} && $cookie{mobirc_key}->value eq _calc_digest($conf->{password}) )
    {
        DEBUG "cookie auth succeeded";
        return true;
    }
    else {
        DEBUG "invalid cookie? $cookie{mobirc_key}";
        return false;
    }
}

sub _set_cookie {
    my ($c, $response, $conf) = @_;

    my $password = $conf->{password} or croak "conf->{password} missing";

    $response->push_header(
        'Set-Cookie' => CGI::Cookie->new(
            -name    => 'mobirc_key',
            -value   => _calc_digest($password),
            -expires => $conf->{expires} || '+7d',
        )
    );
}

1;

__END__

=head1 SYNOPSIS

  - module: Mobirc::Plugin::Authorizer::Cookie
    config:
      password: 0721
      expires: +7d
      # expires: see perldoc CGI

=head1 WARNINGS

this module have may security issue.

=head1 AUTHOR

Tokuhiro Matsuno

