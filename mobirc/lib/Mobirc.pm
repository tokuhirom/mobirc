package Mobirc;
use strict;
use warnings;
use Scalar::Util qw/blessed/;
use POE;
use Mobirc::ConfigLoader;
use Mobirc::Util;
use Mobirc::HTTPD;
use Mobirc::IRCClient;
use UNIVERSAL::require;
use Carp;

our $VERSION = 0.01;

my $context;
sub context { $context }

sub new {
    my ($class, $config_stuff) = @_;
    my $config = Mobirc::ConfigLoader->load($config_stuff);
    my $self = bless {config => $config}, $class;

    $self->load_plugins;

    $context = $self;

    return $self;
}

sub load_plugins {
    my ($self,) = @_;
    die "this is instance method" unless blessed $self;

    for my $plugin (@{$self->config->{plugin}}) {
        DEBUG "LOAD PLUGIN: $plugin->{module}";
        $plugin->{module}->use or die $@;
        $plugin->{module}->register( $self, $plugin->{config} );
    }
}

sub config { shift->{config} }

sub run {
    my $self = shift;
    die "this is instance method" unless blessed $self;

    # TODO: pluggable?
    Mobirc::IRCClient->init($self->config, $self);
    Mobirc::HTTPD->init($self->config);

    $poe_kernel->run();
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
    return $self->{hooks}->{$hook_point} || [];
}

1;
