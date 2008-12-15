package Class::Component::Component::Autocall::Autoload;

use strict;
use warnings;

use Carp::Clan qw/Class::Component/;

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    return unless ref($self);
    (my $method = $AUTOLOAD) =~ s/.*:://;
    return if $method eq 'DESTROY';

    eval {
#        $self->SUPER::can('AUTOLOAD')->(@_) if $self->SUPER::can('AUTOLOAD');
#        $self->SUPER::can($method)->(@_) if $self->SUPER::can($method);
        $self->NEXT($method => @_);
    };
    my $super_error = $@;

    if (ref($self) && (my $plugin = $self->class_component_methods->{$method})) {
        return $self->call($method, @_);
    }
    
    croak $super_error if $super_error;
    croak sprintf('Can\'t locate object method "%s" via package "%s"', $method, ref($self) || $self);
}

1;
