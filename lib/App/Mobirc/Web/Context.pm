package App::Mobirc::Web::Context;
use Mouse;
use HTTP::MobileAttribute;

has session => (
    is       => 'rw',
    isa      => 'HTTP::Session',
    required => 1,
);

has req => (
    is       => 'rw',
    isa      => 'HTTP::Engine::Request',
    required => 1,
);

has mobile_attribute => (
    is => 'rw',
    default => sub {
        my $self = shift;
        HTTP::MobileAttribute->new($self->req->headers)
    },
    lazy => 1,
);

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
