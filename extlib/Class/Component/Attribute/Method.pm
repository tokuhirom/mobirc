package Class::Component::Attribute::Method;

use strict;
use warnings;
use base 'Class::Component::Attribute';

sub register {
    my($class, $plugin, $c, $method, $value) = @_;

    if ($value) {
        $c->register_method( $value => { plugin => $plugin, method => $method } );
    } else {
        $c->register_method( $method => $plugin );
    }
}

1;
