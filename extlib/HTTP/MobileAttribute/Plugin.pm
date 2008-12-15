package HTTP::MobileAttribute::Plugin;
use strict;
use warnings;
use base qw/Class::Component::Plugin/;

__PACKAGE__->mk_classdata('depends' => []);

sub register {
    my ($self, $c) = @_;

    $c->autoload_plugins( @{ $self->depends } );
    $self->SUPER::register($c);
}

sub class_component_load_attribute_resolver {
    $_[1] eq 'CarrierMethod' ? "HTTP::MobileAttribute::Attribute::CarrierMethod" : undef
}

1;
