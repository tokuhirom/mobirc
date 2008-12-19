package HTML::AutoForm::Field::Textarea;

use strict;
use warnings;
use utf8;

our @ISA;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field::AnyText);
};

sub type { 'textarea' }

sub render {
    my ($self, $values) = @_;
    return HTML::AutoForm::_build_element(
        'textarea',
        {
            class => $HTML::AutoForm::CLASS_PREFIX . '_field_' . $self->type,
            %$self,
        },
        {},
        {
            %HTML::AutoForm::Field::AnyText::Defaults,
            value => 1,
        },
        HTML::AutoForm::_escape_html(
            $values && @$values ? $values->[0] : $self->{value} || ''
        ),
    );
}

1;
