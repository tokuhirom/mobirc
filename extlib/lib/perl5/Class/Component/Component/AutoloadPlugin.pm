package Class::Component::Component::AutoloadPlugin;
use strict;
use warnings;

sub autoload_plugins {
    my($class, @plugins) = @_;

    for my $plugin (@plugins) {
        my $name = ref $plugin ? $plugin->{module} : $plugin;
        unless (_is_loaded($class, $name)) {
            $class->load_plugins($plugin);
        }
    }
}

sub _is_loaded {
    my ($c, $stuff) = @_;

    my $base = ref $c || $c;

    for my $plugin (@{ $c->class_component_plugins }) {
        my $module = ref $plugin;
        my $pkg = $stuff;
        unless (($pkg = $stuff) =~ s/^\+//) {
            $module =~ s/^$base\::Plugin\:://;
        }
        return 1 if $pkg eq $module;
    }

    return;
}

1;
