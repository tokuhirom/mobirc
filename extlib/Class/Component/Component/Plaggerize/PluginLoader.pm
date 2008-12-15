package Class::Component::Component::Plaggerize::PluginLoader;
use strict;
use warnings;

sub setup_config {
    my $class = shift;
    my $config = $class->NEXT( setup_config => @_ );

    $config->{global} = {} unless $config->{global};
    $config->{global}->{pluginloader} = {} unless $config->{global}->{pluginloader};
    my $conf = $config->{global}->{pluginloader};
    $conf->{plugin_list}   ||= 'plugins';

    $config;
}

sub setup_plugins {
    my $self = shift;

    my @plugins;
    my $plugin_list = $self->conf->{global}->{pluginloader}->{plugin_list};
    for my $plugin (@{ $self->conf->{$plugin_list} }) {
        push @plugins, { module => $plugin->{module}, config => $plugin };
    }
    $self->load_plugins(@plugins);

    $self->NEXT( setup_plugins => @_ );
}

1;
