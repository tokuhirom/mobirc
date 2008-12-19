use strict;
use warnings;
use utf8;

BEGIN {
    $HTML::AutoForm::Error::Errors{ja} = {
        %{$HTML::AutoForm::Error::Errors{en}},
        CHOICES_TOO_FEW => sub {
            my $self = shift;
            return $self->field->label . 'を入力／選択してください'
                unless $self->field->allow_multiple;
            $self->field->label . 'の選択が少なすぎます';
        },
        CHOICES_TOO_MANY => sub {
            my $self = shift;
            $self->field->label . 'の選択が多すぎます';
        },
        NO_SELECTION => sub {
            my $self = shift;
            $self->field->label . 'を選択してください',
        },
        INVALID_INPUT => sub {
            my $self = shift;
            '不正な入力値です (' . $self->field->label . ')';
        },
        IS_EMPTY => sub {
            my $self = shift;
            $self->field->label . 'を入力してください';
        },
        TOO_SHORT => sub {
            my $self = shift;
            $self->field->label . 'が短すぎます';
        },
        TOO_LONG => sub {
            my $self = shift;
            $self->field->label . 'が長すぎます';
        },
        INVALID_DATA => sub {
            my $self = shift;
            $self->field->label . 'の入力を確認してください',
        },
    };
};

1;
