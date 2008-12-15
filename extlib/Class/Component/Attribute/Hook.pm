package Class::Component::Attribute::Hook;

use strict;
use warnings;
use base 'Class::Component::Attribute';

sub register {
    my($class, $plugin, $c, $method, $value) = @_;

    $value ||= $method;
    $c->register_hook( $value => { plugin => $plugin, method => $method } );
}

1;
