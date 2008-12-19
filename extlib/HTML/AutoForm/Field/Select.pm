package HTML::AutoForm::Field::Select;

use strict;
use warnings;
use utf8;

our @ISA;
our %Defaults;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field);
    %Defaults = (
        multiple => undef,
        options  => undef, # instantiated in constructor
    );
    Class::Accessor::Lite->mk_accessors(keys %Defaults);
};

sub new {
    my $klass = shift;
    my $self = $klass->SUPER::new(@_);
    my @options; # build new list
    if (my $in = $self->{options}) {
        die 'options not in value => attributes form'
            unless @$in % 2 == 0;
        for (my $i = 0; $i < @$in; $i += 2) {
            my $value = $in->[$i];
            my $attributes = $in->[$i + 1];
            push @options, HTML::AutoForm::Field::Option->new(
                %$attributes,
                value  => $value,
            );
        }
    }
    $self->{options} = \@options;
    $self;
}

sub type { 'select' }

sub allow_multiple {
    goto \&multiple;
}

sub render {
    my ($self, $values) = @_;
    return HTML::AutoForm::_build_element(
        'select',
        {
            class => $HTML::AutoForm::CLASS_PREFIX . '_field_' . (
                $self->multiple ? 'multiple' : 'select',
            ),
            %$self,
        },
        {},
        { options => 1, },
        join('', map { $_->render($values) } @{$self->{options}}),
    );
}

sub _per_field_validate {
    goto \&HTML::AutoForm::Field::_validate_choice;
}

1;
