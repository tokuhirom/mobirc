package HTTP::Engine::Interface;
use Mouse;
use UNIVERSAL::require;

my $ARGS;

sub init_class {
    my $klass = shift;
    my $meta = Mouse::Meta::Class->initialize($klass);
    $meta->superclasses('Mouse::Object')
      unless $meta->superclasses;

    no strict 'refs';
    no warnings 'redefine';
    *{ $klass . '::meta' } = sub { $meta };
}

sub import {
    my $class = shift;

    my $caller  = caller(0);
    return if $caller eq 'main';

    $ARGS->{$caller} = {@_};

    no strict 'refs';
    *{"$caller\::__INTERFACE__"} = sub {
        my $caller = caller(0);
        __INTERFACE__($caller);
    };

    strict->import;
    warnings->import;

    init_class($caller);

    Mouse->export_to_level( 1 );
}

# fix up Interface.
sub __INTERFACE__ {
    my ($caller, ) = @_;

    my %args = %{ delete $ARGS->{$caller} };

    my $builder = delete $args{builder} or die "missing builder";
    my $writer  = delete $args{writer}  or die "missing writer";

    _setup_builder($caller, $builder);
    _setup_writer($caller,  $writer);

    Mouse::Util::apply_all_roles($caller, 'HTTP::Engine::Role::Interface');

    $caller->meta->make_immutable(inline_destructor => 1);

    "END_OF_MODULE";
}

sub _setup_builder {
    my ($caller, $builder ) = @_;
    $builder = ($builder =~ s/^\+(.+)$//) ? $1 : "HTTP::Engine::RequestBuilder::$builder";
    unless ($builder->can('meta')) {
        $builder->require or die $@;
    }
    my $instance = $builder->new;

    no strict 'refs';
    *{"$caller\::request_builder"} = sub { $instance };
}

sub _setup_writer {
    my ($caller, $args) = @_;

    my $writer = _construct_writer($caller, $args)->new;
    no strict 'refs';
    *{"$caller\::response_writer"} = sub { $writer };
}

sub _construct_writer {
    my ($caller, $args, ) = @_;

    my $writer = $caller . '::ResponseWriter';
    init_class($writer);

    {
        no strict 'refs';

        my @roles;
        my $apply = sub { push @roles, "HTTP::Engine::Role::ResponseWriter::$_[0]" };
        if ($args->{finalize}) {
            *{"$writer\::finalize"} = $args->{finalize};
        } else {
            if ($args->{response_line}) {
                $apply->('ResponseLine');
            }
            if (my $code = $args->{output_body}) {
                *{"$writer\::output_body"} = $code;
            } else {
                $apply->('OutputBody');
            }
            if (my $code = $args->{write}) {
                *{"$writer\::write"} = $code;
            } else {
                $apply->('WriteSTDOUT');
            }
            $apply->('Finalize');
        }
        for my $role (@roles, 'HTTP::Engine::Role::ResponseWriter') {
            Mouse::Util::apply_all_roles($writer, $role);
        }
    }

    for my $before (keys %{ $args->{before} || {} }) {
        $writer->meta->add_before_method_modifier( $before => $args->{before}->{$before} );
    }
    for my $attribute (keys %{ $args->{attributes} || {} }) {
        Mouse::Meta::Attribute->create( $writer->meta, $attribute,
            %{ $args->{attributes}->{$attribute} } );
    }

    $writer->meta->make_immutable(inline_destructor => 1);

    return $writer;
}

1;
