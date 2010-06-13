package Class::Component::Plugin;

use strict;
use warnings;
use base qw( Class::Accessor::Fast Class::Data::Inheritable );

__PACKAGE__->mk_accessors(qw/ config /);
__PACKAGE__->mk_classdata( '__attr_cache' => {} );
__PACKAGE__->mk_classdata( '__methods_cache' );

use Carp::Clan qw/Class::Component/;
use Class::Inspector;
use UNIVERSAL::require;

sub new {
    my($class, $config, $c) = @_;
    my $self = bless {}, $class;
    $self->config($config);
    $self->init($c);
    $self;
}

sub init {}

my %attribute_detect_cache = ();
sub class_component_plugin_attribute_detect_cache_enable { 1 };
sub class_component_plugin_attribute_detect {
    my($self, $attr, $cache_key) = @_;
    $attribute_detect_cache{$cache_key} = [];

    return unless my($key, $value) = ($attr =~ /^(.*?)(?:\(\s*(.+?)\s*\))?$/);
    unless (defined $value) {
        $attribute_detect_cache{$cache_key} = [$key, $value];
        return ($key, $value);
    }

    my $pkg    = ref $self;
    # from Attribute::Handlers
    my $evaled = eval "package $pkg; no warnings; local \$SIG{__WARN__} = sub{ die \@_ }; [$value]"; ## no critic
    $@ and croak "$pkg: $value: $@";
    my $data   = $evaled || [$value];
    $value     = (@{ $data } > 1) ? $data : $data->[0];

    $attribute_detect_cache{$cache_key} = [$key, $value];
    return ($key, $value);
}

sub class_component_load_attribute_resolver { }

sub register {
    my($self, $c) = @_;

    unless ($self->__methods_cache) {
        my @methods;
        for my $method (@{ Class::Inspector->methods(ref $self) || [] }) {
            next unless my $code = $self->can($method);
            next unless my $attrs = $self->__attr_cache->{$code};
            push @methods, { method => $method, code => $code, attrs => $attrs };
        }
        $self->__methods_cache( \@methods );
    }

    my $is_attribute_detect_cache = $self->class_component_plugin_attribute_detect_cache_enable;
    my $class = ref $self;
    for my $data (@{ $self->__methods_cache }) {
        for my $attr (@{ $data->{attrs} }) {
            my($key, $value);
            my $cache_key = "$class\::$attr";
            my $attr_res  = $attribute_detect_cache{$cache_key};
            if ($is_attribute_detect_cache && $attr_res) {
                ($key, $value) = ( $attr_res->[0], $attr_res->[1] );
            } else {
                next unless ($key, $value) = $self->class_component_plugin_attribute_detect($attr, $cache_key);
            }

            my $attr_class;
            if (my $pkg = $self->class_component_load_attribute_resolver($key)) {
                $pkg->require or croak $@;
                $attr_class = $pkg;
            } else {
                $attr_class = Class::Component::Implement->pkg_require($c => "Attribute::$key");
            }
            unless ($attr_class) {
                next unless $@;
                croak "'$key' is not supported attribute";
            }
            $attr_class->register($self, $c, $data->{method}, $value, $data->{code});
        }
    }
}

sub MODIFY_CODE_ATTRIBUTES {
    my($class, $code, @attrs) = @_;
    $class->__attr_cache->{$code} = [@attrs];
    return ();
}

1;
__END__

=head1 NAME

Class::Component::Plugin - plugin base for pluggable component framework

=head1 SYNOPSIS

Your plugins should succeed to Class::Component::Plugin by your name space, and use it. 

    package MyClass::Plugin;
    use strict;
    use warnings;
    use base 'Class::Component::Plugin';
    1;

for instance, the init phase is rewritten. 

    package MyClass::Plugin;
    use strict;
    use warnings;
    use base 'Class::Component::Plugin';
    __PACKAGE__->mk_accessors(qw/ base_config /);

    sub init {
        my($self, $c) = @_;
        $self->base_config($self->config);
        $self->config($self->config->{config});
    }
    1;


    package MyClass::Plugin::Hello;
    use strict;
    use warnings;
    use base 'MyClass::Plugin';
    sub hello :Method {
        my($self, $context, $args) = @_;
        'hello'
    }
    sub hello_hook :Hook('hello') {
        my($self, $context, $args) = @_;
        'hook hello'
    }

can use alias method name

    sub foo :Method('bar') {}

    $self->call('bar'); # call foo method

default hook name is method name if undefined Hook name

    sub defaulthook :Hook {}

    $self->run_hook( 'defaulthook' );


=head1 HOOK POINTS

=over 4

=item init

init phase your plugins

=item class_component_plugin_attribute_detect

=item class_component_plugin_attribute_detect_cache_enable

1 = using attribute detect cache
0 = not use cache

=item class_component_load_attribute_resolver

attribute name space detector

=back

=head1 ATTRIBUTES

=over 4

=item Method

register_method is automatically done. 

=item Hook

register_hook is automatically done. 

=back

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 SEE ALSO

L<Class::Component>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
