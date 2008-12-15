package HTTP::MobileAttribute::Request::Apache;
use strict;
use warnings;
use Scalar::Util qw/blessed/;

sub new {
    my ($class, $stuff) = @_;

    return bless { r => $stuff }, __PACKAGE__; 
}

sub get {
    my ($self, $header) = @_;
    return $self->{r}->header_in($header);
}

1;
