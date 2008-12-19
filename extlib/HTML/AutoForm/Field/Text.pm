package HTML::AutoForm::Field::Text;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::AnyText);
};

sub type { 'text' }

1;
