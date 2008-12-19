package HTML::AutoForm::Field;

use strict;
use warnings;
use utf8;

our %Defaults;

BEGIN {
    %Defaults = (
        name           => undef,
        # attributes below are for validation
        label          => undef,
        required       => undef,
        custom         => undef,
        allow_multiple => undef,
        xhtml_compat   => 1,
    );
    Class::Accessor::Lite->mk_accessors(keys %Defaults);
};

sub new {
    my $klass = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    for my $n qw(name) {
        die 'mandotory attribute "' . $n . '" is missing'
            unless $args{$n};
    }
    my $self = bless {
        %Defaults,
        %args,
    }, $klass;
    delete $self->{type}; # just to make sure
    $self->{label} ||= ucfirst($self->{name});
    $self;
}

sub choices_minmax {
    my $self = shift;
    
    my $req = $self->required;
    return @$req
        if ref $req eq 'ARRAY';
    return ($req, $req)
        if $req;
    return (0, $self->allow_multiple ? 999999 : 1);
}

sub validate {
    my ($self, $query) = @_;
    my @values = $query->param($self->name);
    
    # check numbers
    my ($min_choices, $max_choices) = $self->choices_minmax();
    if (@values < $min_choices) {
        return HTML::AutoForm::Error->CHOICES_TOO_FEW($self);
    }
    if ($max_choices < @values) {
        return HTML::AutoForm::Error->CHOICES_TOO_MANY($self);
    }
    
    # simply return if the field was optional and there is no data
    return
        unless @values;
    
    # call type-dependent logic
    if (my $error = $self->_per_field_validate($query)) {
        return $error;
    }
    
    # call custom logic
    if (my $f = $self->custom) {
        if (my $error = $f->($self, $query)) {
            return $error;
        }
    }
    
    return;
}

sub _validate_choice {
    my ($self, $query) = @_;
    my $options = $self->options;
    for my $value ($query->param($self->name)) {
        return HTML::AutoForm::Error->NO_SELECTION($self)
            if $value eq '';
        return HTML::AutoForm::Error->INVALID_INPUT($self)
            unless scalar grep { $value eq $_->value } @$options;
    }
    return;
}

1;
