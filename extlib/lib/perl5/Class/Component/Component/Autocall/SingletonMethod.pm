package Class::Component::Component::Autocall::SingletonMethod;

use strict;
use warnings;

use Carp::Clan qw/Class::Component/;

my $instance_counter = 0;
my $alloc_map = {};
sub register_method {
    my($self, @methods) = @_;

    $self->NEXT( register_method => @methods );

    my %add_methods;
    while (my($method, $plugin) = splice @methods, 0, 2) {
        $add_methods{$method} = $plugin
    }
    return unless %add_methods;

    my $singleton_class;
    my $pkg = ref($self);
    unless ($pkg =~ /::_Singletons::\d+$/) {
        $singleton_class = "$pkg\::_Singletons::";
        my $count;
        for my $c (0..$instance_counter) {
            no strict 'refs';
            next if $alloc_map->{"$singleton_class$c"};
            $count = $c;
            last;
        }
        $count = ++$instance_counter unless defined $count;
        $singleton_class .= $count;
	$alloc_map->{$singleton_class} = 1;
        
        { no strict 'refs'; @{"$singleton_class\::ISA"} = $pkg; }
        bless $self, $singleton_class if ref($self);
        Class::Component::Implement->component_isa_list->{$singleton_class} = Class::Component::Implement->component_isa_list->{$pkg};
    } else {
        $singleton_class = $pkg;
    }

    for my $method (keys %add_methods) {
        no strict 'refs';
        *{"$singleton_class\::$method"} = sub { shift->call($method, @_) };
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

sub DESTROY {
    my $self = shift;
    $self->remove_method(%{ $self->class_component_methods });
    $self->class_component_clear_isa_list;
    delete $alloc_map->{ref $self};
}

1;
