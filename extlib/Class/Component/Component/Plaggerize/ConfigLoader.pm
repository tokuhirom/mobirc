package Class::Component::Component::Plaggerize::ConfigLoader;
use strict;
use warnings;

use YAML ();

sub setup_config {
    my $class = shift;
    my($config_file) = @_;

    my $config = $class->NEXT( setup_config => @_ );
    $config_file = $config || $config_file || {};
    return $config_file if ref($config_file);

    open my $fh, '<:utf8', $config_file or die $!;
    $config = YAML::LoadFile($fh);
    close $fh;

    $config;
}

1;
