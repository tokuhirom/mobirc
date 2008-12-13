package MouseX::Plaggerize;
use strict;
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
    Class::MOP::load_class($module);
    my $plugin = $module->new($args->{config} || {});
    $plugin->register( $self );
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
__END__

=for stopwords plagger API

=encoding utf8

=head1 NAME

MouseX::Plaggerize - plagger like plugin feature for Mouse

=head1 SYNOPSIS

    # in main
    my $c = Your::Context->new;
    $c->load_plugin('HTMLFilter::StickyTime');
    $c->load_plugin({module => 'HTMLFilter::DocRoot', config => { root => '/mobirc/' }});
    $c->run();

    package Your::Context;
    use Mouse;
    with 'MouseX::Plaggerize';

    sub run {
        my $self = shift;
        $self->run_hook('response_filter' => $args);
    }

    package Your::Plugin::HTMLFilter::DocRoot;
    use strict;
    use MouseX::Plaggerize::Plugin;

    has root => (
        is       => 'ro',
        isa      => 'Str',
        required => 1,
    );

    hook 'response_filter' => sub {
        my ($self, $context, $args) = @_;
    };

=head1 WARNING!! WARNING!!

THIS MODULE IS IN ITS BETA QUALITY. API MAY CHANGE IN THE FUTURE.

=head1 DESCRIPTION

MouseX::Plaggerize is Plagger like plugin system for Mouse.

MouseX::Plaggerize is a Mouse::Role.You can use this module with 'with'.

=head1 METHOD

=over 4

=item $self->load_plugin({ module => $module, config => $conf)

if you write:

    my $app = MyApp->new;
    $app->load_plugin({ module => 'Foo', config => {hoge => 'fuga'})

above code executes follow code:

    my $app = MyApp->new;
    my $plugin = MyApp::Plugin::Foo->new({hoge => 'fuga'});
    $plugin->register( $app );

=item $self->register_hook('hook point', $plugin, $code)

register code to hook point.$plugin is instance of plugin.

=item $self->run_hook('finalize', $c)

run hook.

use case: mostly ;-)

=item $self->run_hook_first('hook point', @args)

run hook.

if your hook code returns true value, stop the hook loop(this feature likes OK/DECLINED of mod_perl handler).

(please look source code :)

use case: handler like mod_perl

=item $self->run_hook_filter('hook point', @args)

run hook.

(please look source code :)

use case: html filter

=item $self->get_hook('hook point')

get the codes.

use case: write tricky code :-(

=back

=head1 TODO

no plan :-)

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=head1 SEE ALSO

L<Mouse>, L<Class::Component>, L<Plagger>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
