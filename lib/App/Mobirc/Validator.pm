package App::Mobirc::Validator;
use strict;
use warnings;
use Params::Validate ':all';
use Exporter 'import';

our @EXPORT = 'validate_hook';

my $map = {
    authorize => [
        { can => 'register' },
        { isa => 'App::Mobirc' },
        { isa => 'HTTP::Engine::Request' },
    ],
    response_filter => [
        { can => 'register' },
        { isa => 'App::Mobirc' },
        { isa => 'HTTP::Engine::Response' },
    ],
};

sub validate_hook {
    my ( $hook, @args ) = @_;
    my $rule = $map->{$hook} or die "unknown hook point: $hook";
    validate_pos(@args, @$rule);
}

1;
