package App::Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;
use List::MoreUtils qw/any/;
use Encode;

our @EXPORT = qw/true false DEBUG normalize_channel_name daemonize decorate_irc_color U irc_nick global_context/;

sub true  () { 1 } ## no critic.
sub false () { 0 } ## no critic.

sub global_context () { App::Mobirc->context }

sub U ($) { decode('utf-8', shift) } ## no critic.

sub DEBUG($) { ## no critic.
    my $txt = shift;
    print STDERR "$txt\n" if $ENV{DEBUG};
}

sub irc_nick () { Carp::carp("HOGE"); POE::Kernel->alias_resolve('irc_session')->get_heap->{irc}->nick_name } ## no critic

# -------------------------------------------------------------------------

sub normalize_channel_name {
    local $_ = shift;
    tr/A-Z[\\]^/a-z{|}~/;
    $_;
}

# -------------------------------------------------------------------------

sub daemonize {
    my $pid_fname = shift;

    require Proc::Daemon;
    Proc::Daemon::Init();

    if ( defined $pid_fname ) {
        open my $pid, '>', $pid_fname or die "cannot open pid file: $pid_fname";
        $pid->print("$$\n");
        close $pid;
    }
}

1;
