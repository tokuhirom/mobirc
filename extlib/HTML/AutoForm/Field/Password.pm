package HTML::AutoForm::Field::Password;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::AnyText);
};

sub type { 'password' }

1;
