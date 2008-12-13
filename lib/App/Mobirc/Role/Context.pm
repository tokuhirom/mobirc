package App::Mobirc::Role::Context;
use strict;
use Mouse::Role;

my $context;
sub context { $context }

around 'new' => sub {
    my ($next, @args) = @_;
    my $self = $next->( @args );

    $context = $self;

    return $self;
};

1;
# i know this is f*cking black magick :(
# but, this is very useful :)

