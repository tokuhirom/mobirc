package HTML::AutoForm::Field::InputCheckable;

use strict;
use warnings;
use utf8;

BEGIN {
    Class::Accessor::Lite->mk_accessors(qw(parent value label checked));
};

sub new {
    my $klass = shift;
    my $self = bless {
        @_ == 1 ? %{$_[0]} : @_,
    }, $klass;
    Scalar::Util::weaken($self->{parent});
    $self;
}

sub render {
    my ($self, $values) = @_;
    my %base = (
        %{$self->{parent}},
        %$self,
    );
    $base{id} ||=
        $HTML::AutoForm::CLASS_PREFIX . '_radio_' . int(rand(1000000));
    $base{class} ||=
        $HTML::AutoForm::CLASS_PREFIX . '_field_' . $self->parent->type;
    my $html = join(
        '',
        HTML::AutoForm::_build_element(
            'input',
            \%base,
            {
                type    => $self->parent->type,
                value   => $self->{value},
                ($values
                     ? grep { $_ eq $self->{value} } @$values
                         : $self->{checked})
                    ? (checked => 'checked') : (),
            },
            {
                options => 1,
                parent  => 1,
                checked => 1,
            },
        ),
        '<label for="',
        HTML::AutoForm::_escape_html($base{id}),
        '">',
        HTML::AutoForm::_escape_html($self->{label}),
        '</label>',
    );
    $html;
}

1;
