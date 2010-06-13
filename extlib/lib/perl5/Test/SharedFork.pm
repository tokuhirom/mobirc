package Test::SharedFork;
use strict;
use warnings;
use base 'Test::Builder::Module';
our $VERSION = '0.11';
use Test::Builder 0.32; # 0.32 or later is needed
use Test::SharedFork::Scalar;
use Test::SharedFork::Array;
use Test::SharedFork::Store;
use 5.008000;

my $STORE;

BEGIN {
    $STORE = Test::SharedFork::Store->new(
        cb => sub {
            my $store = shift;
            tie __PACKAGE__->builder->{Curr_Test}, 'Test::SharedFork::Scalar', 0, $store;
            tie @{ __PACKAGE__->builder->{Test_Results} }, 'Test::SharedFork::Array', $store;
        }
    );

    no strict 'refs';
    no warnings 'redefine';
    for my $name (qw/ok skip todo_skip current_test/) {
        my $orig = *{"Test::Builder::${name}"}{CODE};
        *{"Test::Builder::${name}"} = sub {
            local $Test::Builder::Level += 4;
            my @args = @_;
            $STORE->lock_cb(sub {
                $orig->(@args);
            });
        };
    };
}

{
    # backward compatibility method
    sub parent { }
    sub child  { }
    sub fork   { fork() }
}

1;
__END__

=head1 NAME

Test::SharedFork - fork test

=head1 SYNOPSIS

    use Test::More tests => 200;
    use Test::SharedFork;

    my $pid = fork();
    if ($pid == 0) {
        # child
        ok 1, "child $_" for 1..100;
    } elsif ($pid) {
        # parent
        ok 1, "parent $_" for 1..100;
        waitpid($pid, 0);
    } else {
        die $!;
    }

=head1 DESCRIPTION

Test::SharedFork is utility module for Test::Builder.
This module makes forking test!

This module merges test count with parent process & child process.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom  slkjfd gmail.comE<gt>

yappo

=head1 THANKS TO

kazuhooku

konbuizm

=head1 SEE ALSO

L<Test::TCP>, L<Test::Fork>, L<Test::MultipleFork>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
