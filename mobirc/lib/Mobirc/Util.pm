package Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;
use List::MoreUtils qw/any/;
use Encode;

our @EXPORT = qw/true false DEBUG compact_channel_name normalize_channel_name add_message daemonize decorate_irc_color/;

sub true  () { 1 } ## no critic.
sub false () { 0 } ## no critic.

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
    my ( $poe, $channel, $who, $msg, $class ) = @_;
    carp "hmmm... class missing?" unless $class;

    DEBUG "ADD MESSAGE TO $channel($class)";

    # validation
    unless (Encode::is_utf8($msg)) {
        croak "msg shuld be flagged utf8";
    }
    if ($who && !Encode::is_utf8($who)) {
        croak "who shuld be flagged utf8 : $who";
    }
    unless (Encode::is_utf8($channel)) {
        croak "channel shuld be flagged utf8";
    }

    my $heap = $poe->kernel->alias_resolve('irc_session')->get_heap;

    my $config = $heap->{config} or die "missing config in heap";

    my $row = {
        channel => $channel,
        who     => $who,
        msg     => $msg,
        class   => $class,
        time    => time(),
    };

    my $canon_channel = normalize_channel_name($channel);

    # update message log
    $heap->{channel_buffer}->{$canon_channel} ||= [];
    push @{ $heap->{channel_buffer}->{$canon_channel} }, $row;
    if ( @{ $heap->{channel_buffer}->{$canon_channel} } > $config->{httpd}->{lines} ) {
        shift @{$heap->{channel_buffer}->{$canon_channel}}; # trash old one.
    }

    # update recent messages buffer
    $heap->{channel_recent}->{$canon_channel} ||= [];
    push @{$heap->{channel_recent}->{$canon_channel}}, $row;
    if ( @{$heap->{channel_recent}->{$canon_channel}} > $config->{httpd}->{lines}) {
        shift @{$heap->{channel_recent}->{$canon_channel}}; # trash old one.
    }

    # update unread lines
    $heap->{unread_lines}->{$canon_channel} = scalar @{ $heap->{channel_recent}->{$canon_channel} };

    # update keyword buffer.
    if ($row->{class} eq 'notice' || $row->{class} eq 'public') {
        if (any { index($row->{msg}, $_) != -1 } @{$config->{global}->{keywords} || []}) {
            push @{$heap->{keyword_buffer}}, $row;
            if ( @{$heap->{keyword_buffer}} > $config->{httpd}->{lines}) {
                shift @{ $heap->{keyword_buffer} }; # trash old one.
            }

            push @{$heap->{keyword_recent}}, $row;
            if ( @{$heap->{keyword_recent}} > $config->{httpd}->{lines}) {
                shift @{ $heap->{keyword_recent} }; # trash old one.
            }
        }
    }
}

# -------------------------------------------------------------------------

sub daemonize {
    my $pid_fname = shift;

    require Proc::Daemon;
    Proc::Daemon::Init();
    if ( defined $pid_fname ) {
        open \my $pid, '>', $pid_fname or die "cannot open pid file: $pid_fname";
        $pid->print("$$\n");
        close $pid;
    }
}

1;
