package App::Mobirc;
use strict;
use warnings;
use 5.00800;
use Scalar::Util qw/blessed/;
use POE;
use App::Mobirc::ConfigLoader;
use App::Mobirc::Util;
use App::Mobirc::HTTPD;
use UNIVERSAL::require;
use Carp;
use App::Mobirc::Channel;
use Encode;

our $VERSION = '0.03';

our $HasKwalify;
eval {
    require Kwalify;
    $HasKwalify++;
};

my $context;
sub context { $context }

sub new {
    my ($class, $config_stuff) = @_;
    my $config = App::Mobirc::ConfigLoader->load($config_stuff);
    my $self = bless {config => $config, channels => {}}, $class;

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
        if ( $HasKwalify && $plugin->{module}->can('config_schema') ) {
            my $res = Kwalify::validate( $plugin->{module}->config_schema, $plugin->{config} );
            unless ( $res == 1 ) {
                die "config.yaml validation error : $plugin->{module}, $res";
            }
        }
        $plugin->{module}->register( $self, $plugin->{config} );
    }
}

sub config { shift->{config} }

sub run {
    my $self = shift;
    die "this is instance method" unless blessed $self;

    for my $code (@{$self->get_hook_codes('run_component')}) {
        $code->($self);
    }

    App::Mobirc::HTTPD->init($self->config);

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
    croak "hook point missing" unless $hook_point;
    return $self->{hooks}->{$hook_point} || [];
}

# -------------------------------------------------------------------------

sub add_channel {
    my ($self, $channel) = @_;
    croak "missing channel" unless $channel;

    $self->{channels}->{$channel->name} = $channel;
}

sub channels {
    my $self = shift;
    my @channels = values %{ $self->{channels} };
    return wantarray ? @channels : \@channels;
}

sub get_channel {
    my ($self, $name) = @_;
    croak "channel name is flagged utf8" unless Encode::is_utf8($name);
    croak "invalid channel name : $name" if $name =~ / /;
    return $self->{channels}->{$name} ||= App::Mobirc::Channel->new($self, $name);
}

sub delete_channel {
    my ($self, $name) = @_;
    croak "channel name is flagged utf8" unless Encode::is_utf8($name);
    delete $self->{channels}->{$name};
}

1;
__END__

=head1 NAME

App::Mobirc - pluggable IRC to HTTP gateway

=head1 DESCRIPTION

mobirc is a pluggable IRC to HTTP gateway for mobile phones.

=head1 AUTHOR

Tokuhiro Matsuno and Mobirc AUTHORS.

=head1 LICENSE

GPL 2.0 or later.
