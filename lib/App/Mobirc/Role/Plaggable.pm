package App::Mobirc::Role::Plaggable;
use strict;
use warnings;
use Mouse::Role;
use 5.00800;
our $VERSION = '0.04';
use Scalar::Util qw/blessed/;
use Carp;

has __moosex_plaggerize_hooks => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub load_plugin {
    my ($self, $args) = @_;
    $args = {module => $args} unless ref $args;
    my $module = $args->{module};
       $module = $self->resolve_plugin($module);
    Mouse::load_class($module);
    my $plugin = $module->new($args->{config} || {});
    $plugin->register( $self );
    $plugin;
}

sub resolve_plugin {
    my ($self, $module) = @_;
    my $base = blessed $self or croak "this is instance method";
    return ($module =~ /^\+(.*)$/) ? $1 : "${base}::Plugin::$module";
}

sub register_hook {
    my ($self, @hooks) = @_;
    while (my ($hook, $plugin, $code) = splice @hooks, 0, 3) {
        $self->__moosex_plaggerize_hooks->{$hook} ||= [];

        push @{ $self->__moosex_plaggerize_hooks->{$hook} }, +{
            plugin => $plugin,
            code   => $code,
        };
    }
}

sub run_hook {
    my ($self, $hook, @args) = @_;
    return unless my $hooks = $self->__moosex_plaggerize_hooks->{$hook};
    my @ret;
    for my $hook (@$hooks) {
        my ($code, $plugin) = ($hook->{code}, $hook->{plugin});
        my $ret = $code->( $plugin, $self, @args );
        push @ret, $ret;
    }
    \@ret;
}

sub run_hook_first {
    my ( $self, $point, @args ) = @_;
    croak 'missing hook point' unless $point;

    for my $hook ( @{ $self->__moosex_plaggerize_hooks->{$point} } ) {
        if ( my $res = $hook->{code}->( $hook->{plugin}, $self, @args ) ) {
            return $res;
        }
    }
    return;
}

sub run_hook_filter {
    my ( $self, $point, @args ) = @_;
    for my $hook ( @{ $self->__moosex_plaggerize_hooks->{$point} } ) {
        @args = $hook->{code}->( $hook->{plugin}, $self, @args );
    }
    return @args;
}


sub get_hook {
    my ($self, $hook) = @_;
    return $self->__moosex_plaggerize_hooks->{$hook};
}

1;
