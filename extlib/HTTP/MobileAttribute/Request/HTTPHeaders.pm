package HTTP::MobileAttribute::Request::HTTPHeaders;
use strict;
use warnings;

sub new {
    my ($class, $stuff) = @_;
    return bless { r => $stuff }, $class; 
}

sub get {
    my ($self, $header) = @_;
    return $self->{r}->header($header);
}

1;
