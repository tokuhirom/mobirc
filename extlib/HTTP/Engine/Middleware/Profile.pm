package HTTP::Engine::Middleware::Profile;
use HTTP::Engine::Middleware;

with 'HTTP::Engine::Middleware::Role::Logger';

use Carp ();

has profiler_class => (
    is      => 'ro',
    default => 'Runtime',
);

has 'profiler' => (
   is         => 'rw',
   required   => 1,
   lazy_build => 1,
);

has 'config' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

sub _build_profiler {
    my $self = shift;
    my $class = $self->profiler_class;
    $class = "HTTP::Engine::Middleware::Profile::$class"
        unless $class =~ s/^\+//;
    Any::Moose::load_class($class);
    $@ and Carp::croak($@);
    $class->new($self->config);
}


before_handle {
    my ( $c, $self, $req ) = @_; 
    $self->profiler->start(@_);
    $req;
};

after_handle {
    my ( $c, $self, $req, $res ) = @_; 
    $self->profiler->end(@_);
    $self->profiler->report(@_);
    $res;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::Profile - stopwatch for request processing time

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install( 'HTTP::Engine::Middleware::Profile' => {
        logger => sub {
            warn @_;
        },
    });
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 DESCRIPTION

This module profile request processing time.

=head1 AUTHORS

dann

=cut
