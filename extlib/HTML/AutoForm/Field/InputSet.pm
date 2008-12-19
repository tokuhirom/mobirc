package HTML::AutoForm::Field::InputSet;

use strict;
use warnings;
use utf8;

our @ISA;
BEGIN {
    @ISA = qw(HTML::AutoForm::Field);
    Class::Accessor::Lite->mk_accessors(qw(options));
};

sub new {
    my $klass = shift;
    my $self = $klass->SUPER::new(@_);
    my @options; # build new list
    if (my $in = $self->{options}) {
        die 'options should be in value => attributes form'
            unless @$in % 2 == 0;
        for (my $i = 0; $i < @$in; $i += 2) {
            my $value = $in->[$i];
            my $attributes = $in->[$i + 1];
            push @options, HTML::AutoForm::Field::InputCheckable->new(
                label  => ucfirst $value,
                %$attributes,
                value  => $value,
                parent => $self,
            );
        }
    }
    $self->{options} = \@options;
    $self;
}

sub render {
    my ($self, $values) = @_;
    my $html = join(
        ' ',
        map {
            $_->render($values)
        } @{$self->{options}},
    );
    $html;
}

1;
