package Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;
use List::MoreUtils qw/any/;
use Encode;

our @EXPORT = qw/true false DEBUG compact_channel_name normalize_channel_name daemonize decorate_irc_color U/;

sub true  () { 1 } ## no critic.
sub false () { 0 } ## no critic.

sub U ($) { decode('utf-8', shift) } ## no critic.

sub DEBUG($) { ## no critic.
    my $txt = shift;
    print "$txt\n" if $ENV{DEBUG};
}

# -------------------------------------------------------------------------
# shorten channel name

sub compact_channel_name {
    local ($_) = shift;

    # #name:*.jp to %name
    if (s/:\*\.jp$//) {
        s/^#/%/;
    }

    # 末尾の単独の @ は取る (plumプラグインのmulticast.plm対策)
    s/\@$//;

    $_;
}

# -------------------------------------------------------------------------

sub normalize_channel_name {
    local ($_) = shift;
    tr/A-Z[\\]^/a-z{|}~/;
    $_;
}

# -------------------------------------------------------------------------

sub add_message {
    my ( $poe, $channel, $who, $body, $class ) = @_;
    carp "hmmm... class missing?" unless $class;

    DEBUG "ADD MESSAGE TO $channel($class)";

    my $canon_channel = normalize_channel_name($channel);

    Mobirc->context->channels->{$canon_channel}->add_message(
        Mobirc::Message->new(
            who   => $who,
            body  => $body,
            class => $class,
        )
    );
}

# -------------------------------------------------------------------------

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
