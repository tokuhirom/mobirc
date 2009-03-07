package HTTP::Engine::Middleware::Role;
use Any::Moose '::Role';

has 'before_handles' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { +[] },
);

has 'after_handles' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { +[] },
);


has 'logger' => (
    is       => 'rw',
    isa      => 'CodeRef',
    required => 1,
    default  => sub { sub {} },
);

sub log {
    my($self, $level, $msg) = @_;
    $self->logger->( $level => $msg );
}

1;

