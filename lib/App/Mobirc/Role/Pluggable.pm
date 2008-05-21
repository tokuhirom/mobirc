package App::Mobirc::Role::Pluggable;
use strict;
use Moose::Role;
use Carp;
use Scalar::Util qw/blessed/;
use App::Mobirc::Util;

our $HasKwalify;
eval {
    require Kwalify;
    $HasKwalify++;
};

sub load_plugins {
    my ($self,) = @_;
    die "this is instance method" unless blessed $self;

    for my $plugin (@{$self->config->{plugin}}) {
        DEBUG "LOAD PLUGIN: $plugin->{module}";
        $plugin->{module}->use or die $@;
        if ( $HasKwalify && $plugin->{module}->can('config_schema') ) {
            my $res = Kwalify::validate( $plugin->{module}->config_schema, $plugin->{config} );
            unless ( $res == 1 ) {
                die "config.yaml validation error : $plugin->{module}, $res";
            }
        }
        $plugin->{module}->register( $self, $plugin->{config} );
    }
}

sub register_hook {
    my ($self, $hook_point, $code) = @_;
    die "this is instance method" unless blessed $self;
    croak "code required" unless ref $code eq 'CODE';

    push @{$self->{hooks}->{$hook_point}}, $code;
}

sub get_hook_codes {
    my ($self, $hook_point) = @_;
    die "this is instance method" unless blessed $self;
    croak "hook point missing" unless $hook_point;
    return $self->{hooks}->{$hook_point} || [];
}

1;
