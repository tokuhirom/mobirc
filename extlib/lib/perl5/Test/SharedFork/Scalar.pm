package Test::SharedFork::Scalar;
use strict;
use warnings;
use base 'Tie::Scalar';

# create new tied scalar
sub TIESCALAR {
    my ($class, $initial, $share) = @_;
    bless { share => $share }, $class;
}

sub FETCH {
    my $self = shift;
    $self->{share}->get('scalar');
}

sub STORE {
    my ($self, $val) = @_;
    my $share = $self->{share};
    $share->set('scalar' => $val);
}

1;
