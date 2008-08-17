package App::Mobirc::Plugin::Authorizer::Cookie;
use strict;
use MooseX::Plaggerize::Plugin;
use App::Mobirc::Util;
use Carp;
use CGI::Cookie;
use Digest::MD5 ();
use Encode;
use App::Mobirc::Validator;

has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has expires => (
    is      => 'ro',
    isa     => 'Str',
    default => '+7d',
);

hook authorize => sub {
    my ( $self, $global_context, $req, ) = validate_hook('authorize', @_);

    my $cookie_str = $req->header('Cookie');
    unless ($cookie_str) {
        DEBUG "cookie header is empty";
        return false;
    }

    my %cookie = CGI::Cookie->parse($cookie_str); # TODO: use HTTP::Engine::Request's stuff!
    if ( $cookie{mobirc_key} && $cookie{mobirc_key}->value eq _calc_digest($self->password) ) {
        DEBUG "cookie auth succeeded";
        return true;
    }
    else {
        DEBUG "invalid cookie? $cookie{mobirc_key}";
        return false;
    }
};

hook response_filter => sub {
    my ($self, $global_context, $c) = validate_hook('response_filter', @_);

    $c->res->cookies->{mobirc_key} = CGI::Cookie->new(
        -name    => 'mobirc_key',
        -value   => _calc_digest($self->password),
        -expires => $self->expires,
    );
};

our $SALT = 'CSS Nite'; 
sub _calc_digest {
    my ($password, ) = @_;
    return Digest::MD5::md5_hex( "$password,$SALT" );
}

1;

__END__

=head1 SYNOPSIS

  - module: App::Mobirc::Plugin::Authorizer::Cookie
    config:
      password: 0721
      expires: +7d
      # expires: see perldoc CGI

=head1 WARNINGS

this module have may security issue.

=head1 AUTHOR

Tokuhiro Matsuno

