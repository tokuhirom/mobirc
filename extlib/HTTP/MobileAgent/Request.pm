package HTTP::MobileAgent::Request;
use strict;

sub new {
    my($class, $stuff) = @_;
    if (!defined $stuff) {
	bless { env => \%ENV }, 'HTTP::MobileAgent::Request::Env';
    }
    elsif (UNIVERSAL::isa($stuff, 'Apache')) {
	bless { r => $stuff }, 'HTTP::MobileAgent::Request::Apache';
    }
    elsif (UNIVERSAL::isa($stuff, 'HTTP::Headers')) {
	bless { r => $stuff }, 'HTTP::MobileAgent::Request::HTTPHeaders';
    }
    else {
	bless { env => { HTTP_USER_AGENT => $stuff } }, 'HTTP::MobileAgent::Request::Env';
    }
}

package HTTP::MobileAgent::Request::Env;

sub get {
    my($self, $header) = @_;
    $header =~ tr/-/_/;
    return $self->{env}->{"HTTP_" . uc($header)};
}

package HTTP::MobileAgent::Request::Apache;

sub get {
    my($self, $header) = @_;
    return $self->{r}->header_in($header);
}

package HTTP::MobileAgent::Request::HTTPHeaders;

sub get {
    my($self, $header) = @_;
    return $self->{r}->header($header);
}

1;
