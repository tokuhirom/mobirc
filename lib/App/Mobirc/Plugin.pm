package App::Mobirc::Plugin;
use Mouse;
use Scalar::Util qw/blessed/;
use Sub::Exporter;
use Carp;

{
    my $HOOK_STORE = {};

    my %exports = (
        register => sub {
            sub {
                my ( $self, $c ) = @_;
                my $proto = blessed $self or confess "this is instance method: $self";

                for my $row ( @{ $HOOK_STORE->{$proto} || [] } ) {
                    my ( $hook, $code ) = @$row;
                    $c->register_hook( $hook, $self, $code );
                }
            }
        },
        hook => sub {
            sub {
                my ( $hook, $code ) = @_;
                my $caller = caller(0);
                push @{ $HOOK_STORE->{$caller} }, [ $hook, $code ];
            }
        },
    );

    my $exporter = Sub::Exporter::build_exporter(
        {
            exports => \%exports,
            groups  => { default => [':all'] }
        }
    );

    sub import {
        my $caller = caller();

        strict->import;
        warnings->import;

        return if $caller eq 'main';

        my $meta = Mouse::Meta::Class->initialize($caller);
        $meta->superclasses('Mouse::Object')
            unless $meta->superclasses;

        no strict 'refs';
        no warnings 'redefine';
        *{$caller.'::meta'} = sub { $meta };

        for my $keyword (@Mouse::EXPORT) {
            *{ $caller . '::' . $keyword } = *{'Mouse::' . $keyword};
        }

        goto $exporter;
    }
}

1;
