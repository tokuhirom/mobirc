package Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;

our @EXPORT = qw/DEBUG compact_channel_name canon_name add_message daemonize decorate_irc_color/;

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

sub canon_name {
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
        croak "$msg shuld be flagged utf8";
    }
    unless (Encode::is_utf8($channel)) {
        croak "$channel shuld be flagged utf8";
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

    my $canon_channel = canon_name($channel);

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

    # update mtime
    $heap->{channel_mtime}->{$canon_channel} = time;

    # update unread lines
    $heap->{unread_lines}->{$canon_channel} = scalar @{ $heap->{channel_recent}->{$canon_channel} };
    if ( $heap->{unread_lines}->{$canon_channel} > $config->{httpd}->{lines} ) {
        $heap->{unread_lines}->{$canon_channel} = $config->{httpd}->{lines};
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

my %stash; # (?{ code }) makes storange scope ;-( see perldoc perlre.
sub decorate_irc_color {
    my $src = shift;

    $src =~ s{(?:
               \x02(?{ $stash{bold} = 1 })|
               \x1f(?{ $stash{underline} = 1 })|
               \x16(?{ $stash{inverse} = 1 })|
               \x03(?:(\d+)(?:,(\d+))?)
                (?{ $stash{color} = $1; $stash{bgcolor} = $2 })
              )+
               ([^\x0f]*)(?{ $stash{msg} = $3 })
               \x0f}{
                   my $style = '';
                   if ($stash{bold}) {
                       $style .= "font-weight:bold;";
                   }
                   if ($stash{underline}) {
                       $style .= "text-decoration:underline;";
                   }
                   if ($stash{inverse}) {
                       # xxx not sure this is correct
                       @stash{qw(color bgcolor)} = @stash{qw( bgcolor color)};
                   }
                   if ($stash{color}) {
                       if (my $color = irc_color($stash{color})) {
                           $style .= "font-color:$color;";
                       }
                   }
                   if ($stash{bgcolor}) {
                       if (my $color = irc_color($stash{bgcolor})) {
                           $style .= "background-color:$color;";
                       }
                   }
                   my $msg = $stash{msg};
                   %stash = (); # reset
                   qq{<span style="$style">$msg</span>};
               }egx;

    return $src;
}

my %color_table;
BEGIN { %color_table = (
    0  => [qw(white)],
    1  => [qw(black)],
    2  => [qw(blue         navy)],
    3  => [qw(green)],
    4  => [qw(red)],
    5  => [qw(brown        maroon)],
    6  => [qw(purple)],
    7  => [qw(orange       olive)],
    8  => [qw(yellow)],
    9  => [qw(lightt_green lime)],
    10 => [qw(teal)],
    11 => [qw(light_cyan   cyan aqua)],
    12 => [qw(light_blue   royal)],
    13 => [qw(pink         light_purple  fuchsia)],
    14 => [qw(grey)],
    15 => [qw(light_grey   silver)],
   );
}

sub irc_color {
    my $num = shift;
    $color_table{$num}->[0];
}

1;
