package HTML::AutoForm::Error;

use strict;
use warnings;
use utf8;

our %Defaults;
our %Errors;

BEGIN {
    # setup accessor
    Class::Accessor::Lite->mk_accessors(qw/code field args/);
    
    # errors
    $Errors{en} = {
        CHOICES_TOO_FEW => sub {
            my $self = shift;
            return 'Please select / input ' . lcfirst($self->field->label) . '.'
                unless $self->field->allow_multiple;
            'Too few items selected for ' . lcfirst($self->field->label) . '.';
        },
        CHOICES_TOO_MANY => sub {
            my $self = shift;
            'Too many items selected for ' . lcfirst($self->field->label) . '.';
        },
        NO_SELECTION => sub {
            my $self = shift;
            'Please select an item from ' . lcfirst($self->field->label) . '.';
        },
        INVALID_INPUT => sub {
            my $self = shift;
            'Invalid input for ' . lcfirst($self->field->label) . '.';
        },
        IS_EMPTY => sub {
            my $self = shift;
            $self->field->label . ' is empty.';
        },
        TOO_SHORT => sub {
            my $self = shift;
            $self->field->label . ' is too short' . '.';
        },
        TOO_LONG => sub {
            my $self = shift;
            $self->field->label . ' is too long' . '.';
        },
        INVALID_DATA => sub {
            my $self = shift;
            'Please check the value of ' . lcfirst($self->field->label);
        },
        CUSTOM => sub {
            my $self = shift;
            $self->args->[0];
        },
    };
    
    # create instance builders
    for my $n (keys %{$Errors{en}}) {
        no strict 'refs';
        *{$n} = sub {
            shift->_new($n, @_);
        };
    }
};

# always use instance builders declared above
sub _new {
    my ($klass, $code, $field, @args) = @_;
    bless {
        code  => $code,
        field => $field,
        args  => \@args,
    }, $klass;
}

sub message {
    my $self = shift;
    my $lang = shift || $HTML::AutoForm::DEFAULT_LANG;
    require "HTML/AutoForm/Error/${lang}.pm"
            unless exists $Errors{$lang};
    $Errors{$lang}->{$self->{code}}->($self);
}

1;
