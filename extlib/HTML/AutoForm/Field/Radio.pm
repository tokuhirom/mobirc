package HTML::AutoForm::Field::Radio;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::InputSet);
};

sub type { 'radio' }

sub _per_field_validate {
    goto \&HTML::AutoForm::Field::_validate_choice;
}

1;
