package HTTPx::Dispatcher;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.05';
use HTTPx::Dispatcher::Rule;
use Scalar::Util qw/blessed/;
use Carp;
use Exporter 'import';

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

    package Your::Handler;
    use HTTP::Engine;
    use Your::Dispatcher;
    use UNIVERSAL::require;

    HTTP::Engine->new(
        'config.yaml',
        handle_request => sub {
            my $c = shift;
            my $rule = Your::Dispatcher->match($c->req->uri);
            $rule->{controller}->use or die 'hoge';
            my $action = $rule->{action};
            $rule->{controller}->$action( $c->req );
        }
    );

=head1 DESCRIPTION

HTTPx::Dispatcher is URI Dispatcher.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=head1 THANKS TO

lestrrat

=head1 SEE ALSO

L<HTTP::Engine>, L<Routes>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
