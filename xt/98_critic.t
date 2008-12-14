use strict;
use warnings;
use Test::More;

eval {
    require Test::Perl::Critic;
    require Perl::Critic;
    die "oops. very old." if $Perl::Critic::VERSION < 1.082;
    Test::Perl::Critic->import( -profile => 'xt/perlcriticrc');
};
plan skip_all => "Test::Perl::Critic >= 1.082 is not installed." if $@;
all_critic_ok('lib');
