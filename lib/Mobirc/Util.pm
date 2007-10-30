package Mobirc::Util;
use strict;
use warnings;
use base 'Exporter';
use Carp;
use List::MoreUtils qw/any/;
use Encode;

our @EXPORT = qw/true false DEBUG compact_channel_name canon_name add_message daemonize decorate_irc_color/;

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
        croak "msg shuld be flagged utf8";
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

    # update unread lines
    $heap->{unread_lines}->{$canon_channel} = scalar @{ $heap->{channel_recent}->{$canon_channel} };

    # update keyword buffer.
    if ($row->{class} eq 'notice' || $row->{class} eq 'public') {
        # FIXME: shoud use local $YAML::Syck::ImplicitUnicode = 1;
        if (any { index($row->{msg}, $_) != -1 } map { decode('utf8', $_) } @{$config->{global}->{keywords} || []}) {
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

sub decorate_irc_color {
    my $src = shift;

    if ($src !~ /[\x02\x03\x0f\x16\x1f]/) {
	# skip without colorcode
	return $src
    }

    my $colorized = '';
    my %default_state = (
	bold => 0,
	inverse => 0,
	underline => 0,
       );
    my %state = (%default_state);
    my $oldstyle = '';
    my $output_span = sub {
	my $style = '';
	if ($state{bold}) {
	    $style .= "font-weight:bold;";
	}
	if ($state{underline}) {
	    $style .= "text-decoration:underline;";
	}
	if ($state{inverse}) {
	    # xxx not sure this is correct
	    @state{qw(color bgcolor)} = @state{qw(bgcolor color)};
	    # XXX too bad
	    delete $state{inverse};
	}
	if ($state{color}) {
	    if (my $color = irc_color($state{color})) {
		$style .= "color:$color;";
	    }
	}
	if ($state{bgcolor}) {
	    if (my $color = irc_color($state{bgcolor})) {
		$style .= "background-color:$color;";
	    }
	}
	my $output = '';
	if ($oldstyle ne $style) {
	    if ($oldstyle) {
		$output .= '</span>';
	    }
	    if ($style) {
		$output .= qq{<span style="$style">}
	    }
	}
	$oldstyle = $style;
	$output;
    };

    while ($src) {
	if ($src =~ s/^\x02//) {
	    $state{bold} = !$state{bold};
	} elsif ($src =~ s/^\x03(?:(\d{1,2})(?:,(\d{1,2}))?)?//) {
	    # if it has bad color specifiers, just ignore it.
	    $state{color} = int($1) if $1;
	    $state{bgcolor} = int($2) if $2;
	} elsif ($src =~ s/^\x0f//) {
	    %state = (%default_state);
	} elsif ($src =~ s/^\x16//) {
	    $state{inverse} = !$state{inverse};
	} elsif ($src =~ s/^\x1f//) {
	    $state{underline} = !$state{underline};
	} elsif ($src =~ s/^([^\x02\x03\x16\x1f\x0f]+)//) {
	    $colorized .= $output_span->() . $1;
	} else {
	    if ($src =~ s/^(.*)$//) {
		# garbase
		use Data::Dumper;
		DEBUG "garbage: ".Dumper($1);
		$colorized .= $output_span->() . $1;
	    }
	    last;
	}
    }
    %state = (%default_state);
    $colorized .= $output_span->();

    return $colorized;
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
    9  => [qw(lightgreen   lime)],
    10 => [qw(teal)],
    11 => [qw(lightcyan    cyan aqua)],
    12 => [qw(lightblue    royal)],
    13 => [qw(pink         lightpurple  fuchsia)],
    14 => [qw(grey)],
    15 => [qw(lightgrey    silver)],
   );
}

sub irc_color {
    my $num = shift;
    $color_table{$num}->[0];
}

1;
