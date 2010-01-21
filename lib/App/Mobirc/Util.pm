package App::Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;
use List::MoreUtils qw/any/;
use Encode;

our @EXPORT = qw/true false DEBUG normalize_channel_name daemonize decorate_irc_color U global_context/;

sub true  () { 1 } ## no critic.
sub false () { 0 } ## no critic.

sub global_context () { App::Mobirc->context }

sub U ($) { decode('utf-8', shift) } ## no critic.

sub DEBUG($) { ## no critic.
    my $txt = shift;
    print STDERR "$txt\n" if $ENV{DEBUG};
}

# -------------------------------------------------------------------------

sub normalize_channel_name {
    local $_ = shift;
    tr/A-Z[\\]^/a-z{|}~/;
    $_;
}

# -------------------------------------------------------------------------

sub daemonize {
    my $pid_fname = shift;

    if (my $pid = fork) {
        exit 0; 
    } elsif (defined $pid) {
        close(STDIN);
        close(STDOUT);
        close(STDERR);

        open(STDIN,  "+>/dev/null"); ## no critic.
        open(STDOUT, "+>&STDIN");    ## no critic.
        open(STDERR, "+>&STDIN");    ## no critic.
    } else {
        die "fork failed: $@";
    }

    if ( defined $pid_fname ) {
        open my $pid, '>', $pid_fname or die "cannot open pid file: $pid_fname";
        $pid->print("$$\n");
        close $pid;
    }
}

1;
