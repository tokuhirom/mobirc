package App::Mobirc::Model::Message;
use Mouse;

has channel => (
    is       => 'rw',
    isa      => 'Any',
);

has who => (
    is  => 'ro',
    isa => 'Str | Undef',
);

has body => (
    is  => 'ro',
    isa => 'Str',
);

has class => (
    is  => 'ro',
    isa => 'Str',
);

has 'time' => (
    is      => 'ro',
    isa     => 'Int',
    default => sub { time() },
);

__PACKAGE__->meta->make_immutable;
1;
