package App::Mobirc::Web::Context;
use Mouse;

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

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
