package App::Mobirc::Types;
use strict;
use warnings;
use App::Mobirc::ConfigLoader;
use MooseX::Types -declare => [qw/Config/];

{
    subtype Config,
        as 'HashRef';
    
    coerce Config,
        from 'Str' => via { App::Mobirc::ConfigLoader->load($_) };
}

1;
