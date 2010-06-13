package Class::Component::Component::DisableDynamicPlugin;

use strict;
use warnings;

use Carp::Clan qw/Class::Component/;

my %component_params = (
    components => {},
    plugins    => {},
    methods    => {},
    plugins    => {},
);

for my $name (qw/ components plugins /) {
    my $method = "class_component_$name";
    no strict 'refs';
    *{__PACKAGE__."::$method"} = sub {
        my $class = shift;
        $class = ref($class) || $class;
        $component_params{$name}->{$class} = $_[0] if $_[0];
        $component_params{$name}->{$class} = [] unless $component_params{$name}->{$class};
        $component_params{$name}->{$class};
    }
}

for my $name (qw/ methods hooks /) {
    my $method = "class_component_$name";
    no strict 'refs';
    *{__PACKAGE__."::$method"} = sub {
        my $class = shift;
        $class = ref($class) || $class;
        $component_params{$name}->{$class} = $_[0] if $_[0];
        $component_params{$name}->{$class} = {} unless $component_params{$name}->{$class};
        $component_params{$name}->{$class};
    }
}

sub class_component_config {
    my $class = shift;
    return Class::Component::Implement->default_configs->{$class} || {} unless ref($class);
    $class->{_class_component_config} || {};
}

sub load_plugins {
    my($class, @plugins) = @_;
    return if ref($class);

    Class::Component::Implement->load_plugins_default($class, @plugins);
    for my $plugin (@plugins) {
        Class::Component::Implement->_load_plugin($class, $plugin);
    }
}

sub class_component_load_component_init {
    my($class, $c) = @_;

    my $default_components = Class::Component::Implement->default_components->{$c};
    $component_params{components}->{$c} = $default_components if $default_components;

    my $default_plugins = Class::Component::Implement->default_plugins->{$c};
    if ($default_plugins) {
         $c->load_plugins(@{ $default_plugins });
    }
}

1;
