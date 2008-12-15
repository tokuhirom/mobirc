package Class::Component::Component::Autocall::InjectMethod;

use strict;
use warnings;

use Carp::Clan qw/Class::Component/;

sub register_method {
    my($self, @methods) = @_;
    my $class = ref($self) || $self;

    $self->NEXT( register_method => @methods );                                                                                                                
    while (my($method, $plugin) = splice @methods, 0, 2) {
        next unless $plugin;
        no strict 'refs';
        no warnings 'redefine';
        unless (ref $plugin eq 'HASH') {
            *{"$class\::$method"} = sub { $plugin->$method(shift, @_) };
            next;
        }

        # extend method
        my $obj         = $plugin;
        $plugin         = $obj->{plugin};
        my $real_method = $obj->{method};
        next unless $plugin && $real_method;
        if (ref $real_method eq 'CODE') {
            *{"$class\::$method"} = sub { $real_method->($plugin, shift, @_) };
        } elsif (!ref($real_method)) {
            *{"$class\::$method"} = sub { $plugin->$real_method(shift, @_) };
        }
    }
}

sub remove_method {
    my($self, @methods) = @_;
    $self->NEXT( remove_method => @methods );
    while (my($method, $plugin) = splice @methods, 0, 2) {
        no strict 'refs';
        delete ${ref($self) . "::"}{$method};
    }
}

1; 
