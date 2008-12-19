package HTML::AutoForm::Field::Checkbox;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::InputSet);
};

sub type { 'checkbox' }

sub allow_multiple {
    1;
}

sub _per_field_validate {
    goto \&HTML::AutoForm::Field::_validate_choice;
}

1;
