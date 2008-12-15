package Class::Component::Component::Plaggerize;
use strict;
use warnings;
use Carp ();
use UNIVERSAL::require;

sub import {
    my($class, %args) = @_;

    my $config = delete $args{plaggerize} || {};
    $config->{plugins} ||= [qw/ PluginLoader Log ConfigLoader /];

    my @plugins;
    for my $plugin (@{ $config->{plugins} }) {
        my $module = $plugin =~ s/^\+// ? $plugin : "Class::Component::Component::Plaggerize::$plugin";
        $module->require or Carp::croak("Loading $module: $@");
        push @plugins, $module;
    }
    if (@plugins) {
        no strict 'refs';
        my @isa ;
        for my $pkg (@{"$class\::ISA"}) {
            if ($pkg->isa(__PACKAGE__)) {
                push @isa, $pkg, @plugins;
            } else {
                push @isa, $pkg;
            }
        }
        @{"$class\::ISA"} = @isa;

        $class->class_component_clear_isa_list;
    }
    $class->NEXT( import => %args );
}

sub new {
    my($class, $args) = @_;

    my $config = delete $args->{config} || {};
    $args->{config} = {};
    my $self = $class->NEXT( new => $args );

    $self->conf( $class->setup_config($config) );
    $self->setup_plugins;

    $self;
}

sub conf {
    my $self = shift;
    $_[0] ? ( $self->{conf} = $_[0]) : $self->{conf};
}

sub setup_config { shift->NEXT( setup_config => @_ ) }
sub setup_plugins { shift->NEXT( setup_plugins => @_ ) }

sub log { shift->NEXT( log => @_ ) }
sub should_log { shift->NEXT( should_log => @_ ) }

1;

__END__

=head1 NAME

Class::Component::Component::Plaggerize - extend your module like from Plagger component

=head1 SYNOPSIS

myapp.pl

  #!/usr/bin/perl
  use strict;
  use warnings;

  use MyApp;
  MyApp->new({ config => 'config.yaml' })->run;

config.yaml

  plugins:
    - module: Test
      config: hello

MyApp.pm

  package MyApp;
  use strict;
  use warnings;
  use Class::Component;
  __PACKAGE__->load_components(qw/ Plaggerize /);

  sub run {
      my $self = shift;
      $self->log( debug => 'running start' );
      $self->run_hook('test');
  }
  1;

MyApp/Plugin/Test.pm

  package MyApp::Plugin::Test;
  use strict;
  use warnings;
  use base 'Class::Component::Plugin';

  sub test : Hook('test') {
      my($self, $c) = @_;
      use Data::Dumper;
      $c->log( debug => 'testmethod:' . Dumper($self->config) );
  }
  1;

=head1 METHODS

=over 4

=item conf

Returns a hash that has the application-wide configuration. 

=item log

  $self->log( debug => 'debug log');

=item should_log

=back

=head1 SETUP METHODS

=over 4

=item setup_config

=item setup_plugins

=back

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 SEE ALSO

L<Class::Component>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
