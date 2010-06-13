package HTTPx::Dispatcher;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.07';
use HTTPx::Dispatcher::Rule;
use Scalar::Util qw/blessed/;
use Carp;
use base qw/Exporter/;

our @EXPORT = qw/connect match uri_for/;

my $rules;

sub connect {
    my $pkg  = caller(0);
    my @args = @_;

    push @{ $rules->{$pkg} }, HTTPx::Dispatcher::Rule->new(@args);
}

sub match {
    my ( $class, $req ) = @_;
    croak "request required" unless blessed $req;

    for my $rule ( @{ $rules->{$class} } ) {
        if ( my $result = $rule->match($req) ) {
            return $result;
        }
    }
    return;    # no match.
}

sub uri_for {
    my ( $class, @args ) = @_;

    for my $rule ( @{ $rules->{$class} } ) {
        if ( my $result = $rule->uri_for(@args) ) {
            return $result;
        }
    }
}

1;
__END__

=for stopwords TODO URI uri

=encoding utf8

=head1 NAME

HTTPx::Dispatcher - the uri dispatcher

=head1 SYNOPSIS

    package Your::Dispatcher;
    use HTTPx::Dispatcher;

    connect ':controller/:action/:id';

    # in your *.psgi file
    use Plack::Request;
    use Your::Dispatcher;
    use UNIVERSAL::require;

    sub {
        my $req = Plack::Request->new($_[0]);
        my $rule = Your::Dispatcher->match($c->req);
        $rule->{controller}->use or die 'hoge';
        my $action = $rule->{action};
        $rule->{controller}->$action( $c->req );
    };

=head1 DESCRIPTION

HTTPx::Dispatcher is URI Dispatcher.

Easy to integrate with Plack::Request, HTTP::Engine, HTTP::Request, Apache::Request, etc.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=head1 THANKS TO

lestrrat

masaki

=head1 SEE ALSO

L<Plack::Request>, L<HTTP::Engine>, L<Routes>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
