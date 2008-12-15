package HTTP::MobileAttribute::Request::Env;
use strict;
use warnings;

sub new {
    my ($class, $stuff) = @_;

    # %ENV is global, so localize to %env
    my %env = ! defined $stuff ? %ENV : (HTTP_USER_AGENT => $stuff);
    return bless { env => \%env }, $class;
}

sub get {
    my ($self, $header) = @_;
    $header =~ tr/-/_/;
    return $self->{env}->{"HTTP_" . uc($header)};
}

1;
