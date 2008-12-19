package HTML::AutoForm::Field::Hidden;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::AnyText);
};

sub type { 'hidden' }

1;
