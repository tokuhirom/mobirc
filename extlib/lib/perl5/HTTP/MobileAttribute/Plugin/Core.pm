package HTTP::MobileAttribute::Plugin::Core;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;

sub new {
    my ($class, $config, $c) = @_;
    my $self = $class->SUPER::new($config, $c);
    # $c->load_plugins();
    $self;
}

1;
