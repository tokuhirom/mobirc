package App::Mobirc::Plugin;
use strict;
use warnings;
use Mouse;
use base qw/Exporter/;
use Scalar::Util qw/blessed/;
use Carp;

our @EXPORT = qw/register hook/;

{
    {
        my $HOOK_STORE = {};

        sub register {
            my ( $self, $c ) = @_;
            my $proto = blessed $self or confess "this is instance method: $self";

            for my $row ( @{ $HOOK_STORE->{$proto} || [] } ) {
                my ( $hook, $code ) = @$row;
                $c->register_hook( $hook, $self, $code );
            }
        }
        sub hook {
            my ( $hook, $code ) = @_;
            my $caller = caller(0);
            push @{ $HOOK_STORE->{$caller} }, [ $hook, $code ];
        }
    }

    sub import {
        my $caller = caller();

        Mouse->import({into_level => 1});
        __PACKAGE__->export_to_level(1);
    }
}

1;
