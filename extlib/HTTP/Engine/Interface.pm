package HTTP::Engine::Interface;
use Any::Moose;
use Any::Moose (
    '::Util' => [qw/apply_all_roles/],
);

my $ARGS;

sub init_class {
    my $klass = shift;
    my $meta = any_moose('::Meta::Class')->initialize($klass);
    $meta->superclasses(any_moose('::Object'))
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

    any_moose()->import({into_level => 1});
}

# fix up Interface.
sub __INTERFACE__ {
    my ($caller, ) = @_;

    my %args = %{ delete $ARGS->{$caller} };

    my $builder = delete $args{builder} or die "missing builder";
    my $writer  = delete $args{writer}  or die "missing writer";

    _setup_builder($caller, $builder);
    _setup_writer($caller,  $writer);

    apply_all_roles($caller, 'HTTP::Engine::Role::Interface');

    $caller->meta->make_immutable(inline_destructor => 1);

    "END_OF_MODULE";
}

sub _setup_builder {
    my ($caller, $builder ) = @_;
    $builder = ($builder =~ s/^\+(.+)$//) ? $1 : "HTTP::Engine::RequestBuilder::$builder";
    unless ($builder->can('meta')) {
        Any::Moose::load_class($builder);
        $@ and die $@;
    }

    my $instance = $builder->new;
    $caller->meta->add_method(request_builder => sub { $instance });
}

sub _setup_writer {
    my ($caller, $args) = @_;

    my $writer = _construct_writer($caller, $args)->new;
    
    $caller->meta->add_method(response_writer => sub { $writer });
}

sub _construct_writer {
    my ($caller, $args, ) = @_;

    my $writer = $caller . '::ResponseWriter';
    init_class($writer);

    {   
        $writer->meta->make_mutable 
            if Any::Moose::moose_is_preferred() 
            && $writer->meta->is_immutable;        

        my @roles;
        my $apply = sub { push @roles, "HTTP::Engine::Role::ResponseWriter::$_[0]" };
        if ($args->{finalize}) {
            $writer->meta->add_method(finalize => $args->{finalize});               
        } else {
            if ($args->{response_line}) {
                $apply->('ResponseLine');
            }
            if (my $code = $args->{output_header}) {
                $writer->meta->add_method(output_header => $code);
            } else {
                $apply->('OutputHeader');
            }
            if (my $code = $args->{output_body}) {
                $writer->meta->add_method(output_body => $code);
            } else {
                $apply->('OutputBody');
            }
            if (my $code = $args->{write}) {
                $writer->meta->add_method(write => $code);
            } else {
                $apply->('WriteSTDOUT');
            }
            $apply->('Finalize');
        }

        for my $role (@roles, 'HTTP::Engine::Role::ResponseWriter') {
            apply_all_roles($writer, $role);
        }
    }

    for my $before (keys %{ $args->{before} || {} }) {
        $writer->meta->add_before_method_modifier( $before => $args->{before}->{$before} );
    }
    for my $around (keys %{ $args->{around} || {} }) {
        $writer->meta->add_around_method_modifier( $around => $args->{around}->{$around} );
    }
    for my $attribute (keys %{ $args->{attributes} || {} }) {
        $writer->meta->add_attribute( 
            $attribute,
            %{ $args->{attributes}->{$attribute} }
        )
    }

    # FIXME
    $writer->meta->make_immutable(inline_destructor => 1)
        unless Any::Moose::moose_is_preferred();

    return $writer;
}

1;
