package HTTP::MobileAttribute::Request::APRTable;
use strict;
use warnings;

sub new {
    my ($class, $stuff) = @_;
    return bless { r => $stuff }, $class; 
}

sub get {
    my ($self, $header) = @_;
    return $self->{r}->{$header};
}

1;
