package Class::Component;

use strict;
use warnings;
our $VERSION = '0.17';

for my $method (qw/ load_components load_plugins new register_method register_hook remove_method remove_hook call run_hook NEXT /) {
    no strict 'refs';
    *{__PACKAGE__."::$method"} = sub { Class::Component::Implement->$method(@_) };
}

for my $name (qw/ config components plugins methods hooks /) {
    my $method = "class_component_$name";
    no strict 'refs';
    *{__PACKAGE__."::$method"} = sub { 
        $_[0]->{"_$method"} = $_[1] if $_[1];
        $_[0]->{"_$method"}
    };
}

sub import {
    my($class, %args) = @_;
    return unless $class eq 'Class::Component';
    my $pkg = caller(0);

    unless ($pkg->isa('Class::Component')) {
        no strict 'refs';
        unshift @{"$pkg\::ISA"}, $class;
    }

    Class::Component::Implement->init($pkg, %args);
}

sub class_component_load_component_resolver {}
sub class_component_load_plugin_resolver {}

sub class_component_reinitialize {
    my($class, %args) = @_;
    Class::Component::Implement->init($class, %args);
}

sub class_component_clear_isa_list {
    my $class = shift;

    my $klass = $_[0] || ref($class) || $class;
    my $isa_list = Class::Component::Implement->component_isa_list;
    for my $key (keys %{ $isa_list }) {
        delete $isa_list->{$key} if $key =~ /^$klass-/ || $key eq $klass;
    }

    my $pkg_require_cache = Class::Component::Implement->pkg_require_cache;
    for my $key (keys %{ $pkg_require_cache }) {
        delete $pkg_require_cache->{$key} if $key =~ /^$klass\::/ || $key eq $klass;
    }
}

package # hide from PAUSE
    Class::Component::Implement;

use strict;
use warnings;
use base qw( Class::Data::Inheritable );

my $component_isa_list = {};
my $default_components = {};
my $default_plugins    = {};
my $default_configs    = {};
my $reload_plugin_maps = {};

use UNIVERSAL::require;

use Carp::Clan qw/Class::Component/;
use Class::Inspector;

sub component_isa_list { $component_isa_list }
sub default_components { $default_components }
sub default_plugins { $default_plugins }
sub default_configs { $default_configs }

sub init {
    my($class, $c, %args) = @_;
    $c = $class->_class($c);

    $default_components->{$c} ||= [];
    $default_plugins->{$c}    ||= [];
    $default_configs->{$c}    = delete $args{config} if defined $args{config};

    delete $reload_plugin_maps->{$c};
    $reload_plugin_maps->{$c} = \&_reload_plugin if $args{reload_plugin};
}

sub shared_configs {
    my($class, $from, $to) = @_;

    $default_components->{$to} = $default_components->{$from};
    $default_plugins->{$to}    = $default_plugins->{$from};
    $reload_plugin_maps->{$to} = $reload_plugin_maps->{$from};
}

sub load_components {
    my($class, $c, @components) = @_;

    for my $component (@components) {
        $class->_load_component($c, $component);
    }
}

sub _load_component {
    my($class, $c, $component, $reload) = @_;
    $c = $class->_class($c);

    my $pkg;
    if (($pkg = $component) =~ s/^\+// || ($pkg = $c->class_component_load_component_resolver($component))) {
        $pkg->require or croak $@;
    } else {
        unless ($pkg = $class->pkg_require($c => "Component::$component")) {
            $@ and croak $@;
            croak "$component is not installed";
        }
    }

    unless ($reload) {
        for my $default (@{ $default_components->{$c} }) {
            return if $pkg eq $default;
        }
    }

    no strict 'refs';
    unshift @{"$c\::ISA"}, $pkg;
    for my $isa_pkg (@{ $class->isa_list($c) }) {
        my $key = $c;
        my $from;
        unless ($c eq $isa_pkg) {
            $key .= "-$isa_pkg";
            $from = $isa_pkg;
        }
        $class->component_isa_list->{$key} = $class->isa_list($c, $from);
    }
    push @{ $default_components->{$c} }, $pkg unless $reload;
    $pkg->class_component_load_component_init($c) if $pkg->can('class_component_load_component_init');
}

sub load_plugins {
    my($class, $c, @plugins) = @_;

    return $class->load_plugins_default($c, @plugins) unless ref $c;

    for my $plugin (@plugins) {
        $class->_load_plugin($c, $plugin);
    }
}

sub load_plugins_default {
    my($class, $c, @plugins) = @_;

    LOOP:
    for my $plugin (@plugins) {
        for my $default (@{ $default_plugins->{$c} }) {
            next LOOP if $plugin eq $default;
        }
        push @{ $default_plugins->{$c} }, $plugin;
    }
}

sub _load_plugin {
    my($class, $c, $plugin) = @_;

    # config option support
    my $config;
    if (ref($plugin) eq 'HASH') {
        $config = $plugin->{config} || {};
        $plugin = $plugin->{module};
    }
    return unless $plugin;

    my $pkg;
    if (($pkg = $plugin) =~ s/^\+// || ($pkg = $c->class_component_load_plugin_resolver($plugin))) {
        $pkg->require or croak $@;
    } else {
        unless ($pkg = $class->pkg_require($c => "Plugin::$plugin")) {
            $@ and croak $@;
            croak "$plugin is not installed";
        }
    }

    my $class_component_plugins = $c->class_component_plugins;
    unless ($config) {
        for my $default (@{ $class_component_plugins }) {
            return if $pkg eq ref($default);
        }
    }

    my $obj = $pkg->new($config || $c->class_component_config->{$plugin} || {}, $c);
    push @{ $class_component_plugins }, $obj;
    $obj->register($c);
}

sub new {
    my($class, $c, $args) = @_;
    $args ||= {};

    my $self = bless {
        %{ $args },
        _class_component_plugins         => [],
        _class_component_components      => $default_components->{$c},
        _class_component_methods         => {},
        _class_component_hooks           => {},
        _class_component_config          => $args->{config} || $default_configs->{$c} || {},
        _class_component_default_plugins => $default_plugins->{$c},
    }, $c;

    $self->load_plugins(@{ $default_plugins->{$c} }, @{ $args->{load_plugins} || [] });

    $self;
}

sub register_method {
    my($class, $c, @methods) = @_;
    while (my($method, $plugin) = splice @methods, 0, 2) {
        $c->class_component_methods->{$method} = $plugin
    }
}

sub register_hook {
    my($class, $c, @hooks) = @_;
    while (my($hook, $obj) = splice @hooks, 0, 3) {
        $c->class_component_hooks->{$hook} = [] unless $c->class_component_hooks->{$hook};
        push @{ $c->class_component_hooks->{$hook} }, $obj;
    }
}

sub remove_method {
    my($class, $c, @methods) = @_;
    while (my($method, $plugin) = splice @methods, 0, 2) {
        next unless ref($c->class_component_methods->{$method}) eq $plugin;
        delete $c->class_component_methods->{$method};
    }
}

sub remove_hook {
    my($class, $c, @hooks) = @_;
    while (my($hook, $remove_obj) = splice @hooks, 0, 3) {
        my $i = -1;
        for my $obj (@{ $c->class_component_hooks->{$hook} }) {
            $i++;
            next unless ref($obj->{plugin}) eq $remove_obj->{plugin} && $obj->{method} eq $remove_obj->{method};
            splice @{ $c->class_component_hooks->{$hook} }, $i, 1;
        }
        delete $c->class_component_hooks->{$hook} unless @{ $c->class_component_hooks->{$hook} };
    }
}

sub call {
    my($class, $c, $method, @args) = @_;
    return unless my $plugin = $c->class_component_methods->{$method};
    if (ref $plugin eq 'HASH') {
        # extend method
        my $obj         = $plugin;
        $plugin         = $obj->{plugin};
        my $real_method = $obj->{method};
        return unless $plugin && $real_method;
        $class->reload_plugin($c, $plugin);
        if (ref $real_method eq 'CODE') {
            $real_method->($plugin, $c, @args);
        } elsif (!ref($real_method)) {
            $plugin->$real_method($c, @args);
        }
    } else {
        $class->reload_plugin($c, $plugin);
        $plugin->$method($c, @args);
    }
}

sub run_hook {
    my($class, $c, $hook, $args) = @_;
    return unless my $hooks = $c->class_component_hooks->{$hook};
    $class->reload_plugin($c, $hooks->[0]->{plugin});

    my @ret;
    for my $obj (@{ $hooks }) {
        my($plugin, $method) = ($obj->{plugin}, $obj->{method});
        my $ret = $plugin->$method($c, $args);
        push @ret, $ret;
    }
    \@ret;
}

sub _reload_plugin {
    my($class, $c, $pkg) = @_;
    return if Class::Inspector->loaded($class->_class($pkg));

    $default_components->{$class->_class($c)} = $c->class_component_components;
    $default_plugins->{$class->_class($c)}    = $c->class_component_plugins;

    for my $component (@{ $default_components->{$class->_class($c)} }) {
        $class->_load_component($c, '+' . $class->_class($component), 1);
    }

    for my $plugin (@{ $c->class_component_plugins }) {
        $class->_load_plugin($c, '+' . $class->_class($plugin));
    }

}

sub reload_plugin {
    my($class, $c) = @_;
    return unless my $code = $reload_plugin_maps->{$class->_class($c)};
    goto $code;
}

sub NEXT {
    my($class, $c, $method, @args) = @_;
    my $klass  = ref $c || $c;
    my $caller = caller(1);

    my $isa_list_cache = $component_isa_list->{"$klass-$caller"} || $class->isa_list_cache($c, $caller);
    my @isa = @{ $isa_list_cache };

    for my $pkg (@isa) {
        next unless $pkg->can($method);;
        my $next = "$pkg\::$method";
        return $c->$next(@args);
    }

    for my $pkg (@isa) {
        next unless $pkg->can('AUTOLOAD');
        my $next = "$pkg\::$method";
        return $c->$next(@args);
    }
}

sub isa_list_cache {
    my($class, $c, $from) = @_;
    my $key = ref $c || $c;
    $key .= "-$from" if $from;
    $component_isa_list->{$key} = $class->isa_list($c, $from) unless $component_isa_list->{$key};
    $component_isa_list->{$key};
}

sub isa_list {
    my($class, $c, $from) = @_;
    $c = ref $c || $c;

    my $isa_list = $class->_fetch_isa_list($c);
    my $isa_mark = {};
    $class->_mark_isa_list($isa_list, $isa_mark, 0);
    my @isa = $class->_sort_isa_list($isa_list, $isa_mark, 0);

    my @next_classes;
    my $f = 0;
    $f = 1 unless $from;
    for my $pkg (@isa) {
        if ($f) {
            push @next_classes, $pkg;
       } else {
            next unless $pkg eq $from;
            $f = 1;
        }
    }
    \@next_classes;
}

sub _fetch_isa_list {
    my($class, $base) = @_;

    my $isa_list = { pkg => $base, isa => [] };
    no strict 'refs';
    for my $pkg (@{"$base\::ISA"}) {
        push @{ $isa_list->{isa} }, $class->_fetch_isa_list($pkg);
    }
    $isa_list;
}

sub _mark_isa_list {
    my($class, $isa_list, $isa_mark, $nest) = @_;

    for my $list (@{ $isa_list->{isa} }) {
        $class->_mark_isa_list($list, $isa_mark, $nest + 1);
    }
    my $pkg = $isa_list->{pkg};
    $isa_mark->{$pkg} = { nest => $nest, count => 0 } if !$isa_mark->{$pkg} || $isa_mark->{$pkg}->{nest} < $nest;
    $isa_mark->{$pkg}->{count}++;
}

sub _sort_isa_list {
    my($class, $isa_list, $isa_mark, $nest) = @_;

    my @isa;
    my $pkg = $isa_list->{pkg};
    unless (--$isa_mark->{$pkg}->{count}) {
        push @isa, $pkg;
    }

    for my $list (@{ $isa_list->{isa} }) {
        my @ret = $class->_sort_isa_list($list, $isa_mark, $nest + 1);
        push @isa, @ret;
    }

    @isa;
}

sub _class {
    my($class, $c) = @_;
    ref($c) || $c;
}

my $pkg_require_cache = {};
sub pkg_require_cache { $pkg_require_cache }
sub pkg_require_cache_clear { $pkg_require_cache = {} }
sub pkg_require {
    my($class, $c, $pkg) = @_;
    $c = ref $c || $c;

    my $isa_list;
    if ($isa_list = $component_isa_list->{$c}) {
        if (my $cache = $pkg_require_cache->{$pkg}) {
            if ($cache->{isa_list} eq join('-', @{ $isa_list })) {
                return $cache->{pkg};
            }
        }
    }
    $isa_list ||= [];

    my $obj = { isa_list => join('-', @{ $isa_list }) };
    $pkg_require_cache->{$pkg} = $obj;
    for my $isa_pkg (@{ $class->isa_list_cache($c) }) {
        unless ($isa_list) {
            $isa_list = $component_isa_list->{$c};
            $obj->{isa_list} = join('-', @{ $isa_list });
        }

        my $new_pkg  = "$isa_pkg\::$pkg";
        next unless Class::Inspector->installed($new_pkg);
        $new_pkg->require or return;
        $obj->{pkg} = $new_pkg;
        return $new_pkg;
    }
}

package Class::Component;

1;
__END__

=for stopwords Foo

=head1 NAME

Class::Component - pluggable component framework

=head1 SYNOPSIS

base class

  package MyClass;
  use strict;
  use warnings;
  use Class::Component;
  __PACKAGE__->load_component(qw/ Autocall::InjectMethod /);
  __PACKAGE__->load_plugins(qw/ Default /);

application code

  use strict;
  use warnings;
  use MyClass;
  my $obj = MyClass->new({ load_plugins => [qw/ Hello /] });
  $obj->hello; # autocall
  $obj->run_hook( hello => $args );

=head1 DESCRIPTION

Class::Component is pluggable component framework.
The compatibilities such as dump and load such as YAML are good. 

=head1 METHODS

=over 4

=item new

constructor

=item load_components

  __PACKAGE__->load_components(qw/ Sample /);

The candidate is the order of MyClass::Component::Sample and Class::Component::Sample. 
It looks for the module in order succeeded to by @ISA. 
It is used to remove + when there is + in the head. 

=item load_plugins

  __PACKAGE__->load_plugins(qw/ Default /);

The candidate is the MyClass::Plugin::Default.
It looks for the module in order succeeded to by @ISA. 
It is used to remove + when there is + in the head. 

=item register_method

  $obj->register_method( 'method name' => 'MyClass::Plugin::PluginName' );

Method attribute is usually used and set. See Also L<Class::Component::Plugin>. 

=item register_hook

  $obj->register_hook( 'hook name' => { plugin => 'MyClass::Plugin::PluginName', method => 'hook method name' } );

Hook attribute is usually used and set. See Also L<Class::Component::Plugin>.

=item remove_method

  $obj->remove_method( 'method name' => 'MyClass::Plugin::PluginName' );

=item remove_hook

  $obj->remove_hook( 'hook name' => { plugin => 'MyClass::Plugin::PluginName', method => 'hook method name' } );

=item call

  $obj->call('plugin method name' => @args)
  $obj->call('plugin method name' => %args)

=item run_hook

  $obj->run_hook('hook name' => $args)

=back

=head1 PROPERTIES

=over 4

=item class_component_config

=item class_component_components

=item class_component_plugins

=item class_component_methods

=item class_component_hooks

=back

=head1 METHODS for COMPONENT

=over 4

=item NEXT

  $self->NEXT('methods name', @args);

It is behavior near maybe::next::method of Class::C3. 

=item class_component_reinitialize

=back

=head1 INTERFACES

=over 4

=item class_component_load_component_resolver

=item class_component_load_plugin_resolver

Given an (possibly) unqualified plugin name (say, "Foo"), resolves it into
a fully qualified module name (say, "MyApp::Plugin::Foo")

=back

=head1 INITIALIZE OPTIONS

=over 4

=item reload_plugin

  use Class::Component reload_plugin => 1;

or

  MyClass->class_component_reinitialize( reload_plugin => 1 );

Plugin/Component of the object made with YAML::Load etc. is done and require is done automatically. 

=back

=head1 ATTRIBUTES

SEE ALSO Class::Component::Attribute::Method and Class::Component::Attribute::Hook 
test code in ./t directory. (MyClass::Attribute::Test and MyClass::Plugin::ExtAttribute)

=head1 APPENDED COMPONENTS

It is an outline of Components that the bundle is done in Class::Components::Components or less. 

=over 4

=item DisableDynamicPlugin

plugin can be added, lost from new and the object method, and some speeds are improved.

  package MyClass;
  use base 'Class::Component';
  __PACKAGE__->load_components(qw/ DisableDynamicPlugin /);
  package main;
  MyClass->load_plugins(qw/ Test /); # is ok!
  my $obj = MyClass->new;
  $obj->load_plugins(qw/ NoNoNo /); # not loaded
  my $obj2 = MyClass->new({ load_plugins => qw/ OOPS / }); # not loaded

=item Autocall::Autoload

It keeps accessible with method defined by register_method.
using AUTOLOAD.

  package MyClass::Plugin::Test;
  use base 'Class::Component::Plugin';
  sub test :Method { print "plugin load ok" }
  package MyClass;
  use base 'Class::Component';
  __PACKAGE__->load_components(qw/ Autocall::Autoload /);
  package main;
  MyClass->load_plugins(qw/ Test /);
  my $obj = MyClass->new;
  $obj->test; # plugin load ok

=item Autocall::InjectMethod

It is the same as Autocall::Autoload. The method is actually added.

=item Autocall::SingletonMethod

The method is added in the form of singleton method.
It is not influenced by other objects.
It is not possible to use it at the same time as DisableDynamicPlugin.

  package MyClass::Plugin::Test;
  use base 'Class::Component::Plugin';
  sub test :Method { print "plugin load ok" }
  package MyClass;
  use base 'Class::Component';
  __PACKAGE__->load_components(qw/ Autocall::Autoload /);
  package main;
  MyClass->;
  my $obj = MyClass->new({ load_plugins => [qw/ Test /] });
  $obj->test; # plugin load ok
  my $obj2 = MyClass->new;
  $obj2->test; # died

=item AutoloadPlugin

AutoloadPlugin is Plagger->autoload_plugin like

  $c->autoload_plugins({ module => 'Hello' });
  $c->autoload_plugins({ module => 'Hello', config => {} });
  $c->autoload_plugins({ module => '+Foo::Plugin::Hello' });
  $c->autoload_plugins({ module => '+Foo::Plugin::Hello', config => {} });

the under case is same to load_pugins method

  $c->autoload_plugins('Hello');
  $c->autoload_plugins('+Foo::Plugin::Hello');

=back

=head1 COMPONENTS

=over 4

=item Plaggerize

The Plaggerize is extend your module like from L<Plagger> component.

see. L<Class::Component::Component::Plaggerize>

=back

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 THANKS TO

Tokuhiro Matsuno

=head1 SEE ALSO

L<Class::Component::Plugin>

=head1 EXAMPLE

L<HTTP::MobileAttribute>, L<Number::Object>, L<App::MadEye>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
