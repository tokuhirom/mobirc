package HTML::AutoForm::Field::Option;

use strict;
use warnings;
use utf8;

BEGIN {
    Class::Accessor::Lite->mk_accessors(qw(value label selected));
};

sub new {
    my $klass = shift;
    my $self = bless {
        @_ == 1 ? %{$_[0]} : @_,
    }, $klass;
    $self;
}

sub render {
    my ($self, $values) = @_;
    return HTML::AutoForm::_build_element(
        'option',
        $self,
        ($values ? grep { $_ eq $self->{value} } @$values : $self->{selected})
            ? { selected => 'selected' } : {},
        { selected => 1 },
        $self->{label},
    );
}

1;
