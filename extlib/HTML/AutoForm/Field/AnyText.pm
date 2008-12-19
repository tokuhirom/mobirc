package HTML::AutoForm::Field::AnyText;

use strict;
use warnings;
use utf8;

our @ISA;
our %Defaults;

BEGIN {
    @ISA = qw(HTML::AutoForm::Field);
    %Defaults = (
        min_length => undef,
        max_length => undef,
        regexp     => undef,
    );
    Class::Accessor::Lite->mk_accessors(keys %Defaults);
};

sub new {
    my $klass = shift;
    my $self = $klass->SUPER::new(
        %Defaults,
        @_ == 1 ? %{$_[0]} : @_,
    );
    if (my $r = $self->regexp) {
        # special mappings
        if (! ref($r) && $r eq 'email') {
            # from http://www.tt.rim.or.jp/~canada/comp/cgi/tech/mailaddrmatch/
            $self->regexp(qr/^[\x01-\x7F]+@(([-a-z0-9]+\.)*[a-z]+|\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])/oi);
        }
    }
    $self;
}

sub render {
    my ($self, $values) = @_;
    return HTML::AutoForm::_build_element(
        'input',
        {
            ($self->type ne 'hidden' ? (
                class =>
                    $HTML::AutoForm::CLASS_PREFIX . '_field_' . $self->type,
            ) : ()),
            %$self,
        },
        {
            type  => $self->type,
            $values && @$values ? (value => $values->[0]) : (),
        },
        \%Defaults,
    );
}

sub _per_field_validate {
    my ($self, $query) = @_;
    my $value = $query->param($self->name);
    
    if ($value eq '') {
        # is empty
        return unless $self->required;
        return HTML::AutoForm::Error->IS_EMPTY($self);
    }
    if (my $l = $self->min_length) {
        return HTML::AutoForm::Error->TOO_SHORT($self)
            if length($value) < $l;
    }
    if (my $l = $self->max_length) {
        return HTML::AutoForm::Error->TOO_LONG($self)
            if $l < length $value;
    }
    if (my $r = $self->regexp) {
        return HTML::AutoForm::Error->INVALID_DATA($self)
            if $value !~ /$r/;
    }
    
    return;
}

1;
