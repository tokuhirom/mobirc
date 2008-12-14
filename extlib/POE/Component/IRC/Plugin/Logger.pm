package POE::Component::IRC::Plugin::Logger;

use strict;
use warnings;
use Encode qw(decode);
use Encode::Guess;
use Fcntl qw(O_WRONLY O_APPEND O_CREAT);
use File::Spec::Functions qw(catdir catfile);
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Plugin::BotTraffic;
use POE::Component::IRC::Common qw( l_irc parse_user strip_color strip_formatting );
use POSIX qw(strftime);

our $VERSION = '1.8';

sub new {
    my ($package, %self) = @_;
    if (!defined $self{Path}) {
        die "$package requires a Path";
    }
    return bless \%self, $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    
    if (!$irc->isa('POE::Component::IRC::State')) {
        die __PACKAGE__ . ' requires PoCo::IRC::State or a subclass thereof';
    }
    
    if ( !grep { $_->isa('POE::Component::IRC::Plugin::BotTraffic') } values %{ $irc->plugin_list() } ) {
        $irc->plugin_add('BotTraffic', POE::Component::IRC::Plugin::BotTraffic->new());
    }
    
    if ($self->{Restricted}) {
        $self->{dir_perm} = oct 755;
        $self->{file_perm} = oct 644;
    }
    else {
        $self->{dir_perm} = oct 700;
        $self->{file_perm} = oct 600;

    }

    if (! -d $self->{Path}) {
        mkdir $self->{Path}, $self->{dir_perm} or die 'Cannot create directory ' . $self->{Path} . ": $!; aborted";
    }
    
    $self->{irc} = $irc;
    $self->{logging} = { };
    $self->{Private} = 1 if !defined $self->{Private};
    $self->{Public} = 1 if !defined $self->{Public};
    $self->{Format} = {
        '+b'         => sub { my ($nick, $mask) = @_;            "--- $nick sets ban on $mask" },
        '-b'         => sub { my ($nick, $mask) = @_;            "--- $nick removes ban on $mask" },
        '+e'         => sub { my ($nick, $mask) = @_;            "--- $nick sets exempt on $mask" },
        '-e'         => sub { my ($nick, $mask) = @_;            "--- $nick removes exempt on $mask" },
        '+I'         => sub { my ($nick, $mask) = @_;            "--- $nick sets invite on $mask" },
        '-I'         => sub { my ($nick, $mask) = @_;            "--- $nick removes invite on $mask" },
        '+h'         => sub { my ($nick, $subject) = @_;         "--- $nick gives channel half-operator status to $subject" },
        '-h'         => sub { my ($nick, $subject) = @_;         "--- $nick removes channel half-operator status from $subject" },
        '+o'         => sub { my ($nick, $subject) = @_;         "--- $nick gives channel operator status to $subject" },
        '-o'         => sub { my ($nick, $subject) = @_;         "--- $nick removes channel operator status from $subject" },
        '+v'         => sub { my ($nick, $subject) = @_;         "--- $nick gives voice to $subject" },
        '-v'         => sub { my ($nick, $subject) = @_;         "--- $nick removes voice from $subject" },
        '+k'         => sub { my ($nick, $key) = @_;             "--- $nick sets channel keyword to $key" },
        '-k'         => sub { my ($nick) = @_;                   "--- $nick removes channel keyword" },
        '+l'         => sub { my ($nick, $limit) = @_;           "--- $nick sets channel user limit to $limit" },
        '-l'         => sub { my ($nick) = @_;                   "--- $nick removes channel user limit" },
        '+i'         => sub { my ($nick) = @_;                   "--- $nick enables invite-only channel status" },
        '-i'         => sub { my ($nick) = @_;                   "--- $nick disables invite-only channel status" },
        '+m'         => sub { my ($nick) = @_;                   "--- $nick enables channel moderation" },
        '-m'         => sub { my ($nick) = @_;                   "--- $nick disables channel moderation" },
        '+n'         => sub { my ($nick) = @_;                   "--- $nick disables external messages" },
        '-n'         => sub { my ($nick) = @_;                   "--- $nick enables external messages" },
        '+p'         => sub { my ($nick) = @_;                   "--- $nick enables private channel status" },
        '-p'         => sub { my ($nick) = @_;                   "--- $nick disables private channel status" },
        '+s'         => sub { my ($nick) = @_;                   "--- $nick enables secret channel status" },
        '-s'         => sub { my ($nick) = @_;                   "--- $nick disables secret channel status" },
        '+t'         => sub { my ($nick) = @_;                   "--- $nick enables topic protection" },
        '-t'         => sub { my ($nick) = @_;                   "--- $nick disables topic protection" },
        nick_change  => sub { my ($old_nick, $new_nick) = @_;    "--- $old_nick is now known as $new_nick" },
        topic_is     => sub { my ($chan, $topic) = @_;           "--- Topic for $chan is: $topic" },
        topic_change => sub { my ($nick, $topic) = @_;           "--- $nick changes the topic to: $topic" },
        privmsg      => sub { my ($nick, $msg) = @_;             "<$nick> $msg" },
        action       => sub { my ($nick, $action) = @_;          "* $nick $action" },
        join         => sub { my ($nick, $userhost, $chan) = @_; "--> $nick ($userhost) joins $chan" },
        part         => sub {
            my ($nick, $userhost, $chan, $msg) = @_;
            my $line = "<-- $nick ($userhost) leaves $chan";
            $line .= " ($msg)" if $msg ne '';
            return $line;
        },
        quit         => sub {
            my ($nick, $userhost, $msg) = @_;
            my $line = "<-- $nick ($userhost) quits";
            $line .= " ($msg)" if $msg ne '';
            return $line;
        },
        kick         => sub {
            my ($kicker, $victim, $chan, $msg) = @_;
            my $line = "<-- $kicker kicks $victim from $chan";
            $line .= " ($msg)" if $msg ne '';
            return $line;
        },
        topic_set_by => sub {
            my ($chan, $user, $time) = @_;
            my $date = localtime $time;
            return "--- Topic for $chan was set by $user at $date";
        },
    } if !defined $self->{Format};

    $irc->plugin_register($self, 'SERVER', qw(001 332 333 chan_mode ctcp_action bot_ctcp_action bot_msg bot_public join kick msg nick part public quit topic));
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_001 {
    my ($self, $irc) = splice @_, 0, 2;
    $self->{logging} = { };
    return PCI_EAT_NONE;
}

sub S_332 {
    my ($self, $irc) = splice @_, 0, 2;
    my $chan = ${ $_[2] }->[0];
    my $topic = ${ $_[2] }->[1];
    # only log this if we were just joining the channel
    $self->_log_entry($chan, topic_is => $chan, $topic) if !$irc->channel_list($chan);
    return PCI_EAT_NONE;
}

sub S_333 {
    my ($self, $irc) = splice @_, 0, 2;
    my ($chan, $user, $time) = @{ ${ $_[2] } };
    # only log this if we were just joining the channel
    $self->_log_entry($chan, topic_set_by => $chan, $user, $time) if !$irc->channel_list($chan);
    return PCI_EAT_NONE;
}

sub S_chan_mode {
    my ($self, $irc) = splice @_, 0, 2;
    my $nick = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    my $mode = ${ $_[2] };
    my $arg = ${ $_[3] };
    $self->_log_entry($chan, $mode => $nick, $arg);
    return PCI_EAT_NONE;
}

sub S_ctcp_action {
    my ($self, $irc) = splice @_, 0, 2;
    my $sender = parse_user(${ $_[0] });
    my $recipients = ${ $_[1] };
    my $msg = ${ $_[2] };
    for my $recipient (@{ $recipients }) {
        $self->_log_entry($recipient, action => $sender, $msg);
    }
    return PCI_EAT_NONE;
}

sub S_bot_ctcp_action {
    my ($self, $irc) = splice @_, 0, 2;
    my $recipients = ${ $_[0] };
    my $msg = ${ $_[1] };
    for my $recipient (@{ $recipients }) {
        $self->_log_entry($recipient, action => $irc->nick_name(), $msg);
    }
    return PCI_EAT_NONE;
}

sub S_bot_msg {
    my ($self, $irc) = splice @_, 0, 2;
    my $recipients = ${ $_[0] };
    my $msg = ${ $_[1] };
    for my $recipient (@{ $recipients }) {
        $self->_log_entry($recipient, privmsg => $irc->nick_name(), $msg);
    }
    return PCI_EAT_NONE;
}

sub S_bot_public {
    my ($self, $irc) = splice @_, 0, 2;
    my $channels = ${ $_[0] };
    my $msg = ${ $_[1] };
    for my $chan (@{ $channels }) {
        $self->_log_entry($chan, privmsg => $irc->nick_name(), $msg);
    }
    return PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc) = splice @_, 0, 2;
    my ($joiner, $user, $host) = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    $self->_log_entry($chan, join => $joiner, "$user\@$host", $chan);
    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc) = splice @_, 0, 2;
    my $kicker = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    my $victim = ${ $_[2] };
    my $msg = ${ $_[3] };
    $self->_log_entry($chan, kick => $kicker, $victim, $chan, $msg);
    return PCI_EAT_NONE;
}

sub S_msg {
    my ($self, $irc) = splice @_, 0, 2;
    my $sender = parse_user(${ $_[0] });
    my $msg = ${ $_[2] };
    $self->_log_entry($sender, privmsg => $sender, $msg);
    return PCI_EAT_NONE;
}

sub S_nick {
    my ($self, $irc) = splice @_, 0, 2;
    my $old_nick = parse_user(${ $_[0] });
    my $new_nick = ${ $_[1] };
    my $channels = @{ $_[2] }[0];
    for my $chan (@{ $channels }) {
        $self->_log_entry($chan, nick_change => $old_nick, $new_nick);
    }
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc) = splice @_, 0, 2;
    my ($parter, $user, $host) = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    my $msg = ref $_[2] eq 'SCALAR' ? ${ $_[2] } : '';
    $self->_log_entry($chan, part => $parter, "$user\@$host", $chan, $msg);
    return PCI_EAT_NONE;
}

sub S_public {
    my ($self, $irc) = splice @_, 0, 2;
    my $sender = parse_user(${ $_[0] });
    my $channels = ${ $_[1] };
    my $msg = ${ $_[2] };
    for my $chan (@{ $channels }) {
        $self->_log_entry($chan, privmsg => $sender, $msg);
    }
    return PCI_EAT_NONE;
}

sub S_quit {
    my ($self, $irc) = splice @_, 0, 2;
    my ($quitter, $user, $host) = parse_user(${ $_[0] });
    my $msg = ${ $_[1] };
    my $channels = @{ $_[2] }[0];
    for my $chan (@{ $channels }) {
        $self->_log_entry($chan, quit => $quitter, "$user\@$host", $msg);
    }
    return PCI_EAT_NONE;
}

sub S_topic {
    my ($self, $irc) = splice @_, 0, 2;
    my $changer = parse_user(${ $_[0] });
    my $chan = ${ $_[1] };
    my $new_topic = ${ $_[2] };
    $self->_log_entry($chan, topic_change => $changer, $new_topic);
    return PCI_EAT_NONE;
}

sub _log_entry {
    my ($self, $context, $type, @args) = @_;
    my ($date, $time) = split / /, (strftime '%F %T', localtime);
    $context = l_irc $context, $self->{irc}->isupport('CASEMAPPING');

    if ($context =~ /^[#&+!]/) {
        return if !$self->{Public};
    }
    else {
        return if !$self->{Private};
    }

    return if !defined $self->{Format}->{$type};
    
    my $log_file;
    if ($self->{Sort_by_date}) {
        my $log_dir = catdir($self->{Path}, $context);
        if (! -d $log_dir) {
            mkdir $log_dir, $self->{dir_perm}
                or die "Couldn't create directory $log_dir: $!; aborted";
        }
        $log_file = catfile($self->{Path}, $context, "$date.log");
    }
    else {
        $log_file = catfile($self->{Path}, "$context.log");
    }
    
    $log_file = $self->_open_log($log_file);

    if (!$self->{logging}->{$context}) {
        print $log_file "***\n*** LOGGING BEGINS\n***\n";
        $self->{logging}->{$context} = 1;
    }
    my $line = "$time " . $self->{Format}->{$type}->(@args);
    $line = "$date $line" if !$self->{Sort_by_date};
    print $log_file $self->_normalize($line) . "\n";
    return;
}

sub _open_log {
    my ($self, $file_name) = @_;
    sysopen(my $log, $file_name, O_WRONLY|O_APPEND|O_CREAT, $self->{file_perm})
        or die "Couldn't open or create file '$file_name': $!; aborted";
    binmode($log, ':utf8');
    $log->autoflush(1);
    return $log;
}

sub _normalize {
    my ($self, $line) = @_;
    my $utf8 = guess_encoding($line, 'utf8');
    $line = ref $utf8 ? decode('utf8', $line) : decode('cp1252', $line);
    $line = strip_color($line) if $self->{Strip_color};
    $line = strip_formatting($line) if $self->{Strip_formatting};
    return $line;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::Logger - A PoCo-IRC plugin which
logs public and private messages to disk.

=head1 SYNOPSIS

 use POE::Component::IRC::Plugin::Logger;

 $irc->plugin_add('Logger', POE::Component::IRC::Plugin::Logger->new(
     Path    => '/home/me/irclogs',
     Private => 0,
     Public  => 1,
 ));

=head1 DESCRIPTION

POE::Component::IRC::Plugin::Logger is a L<POE::Component::IRC|POE::Component::IRC>
plugin. It logs messages and CTCP ACTIONs to either C<#some_channel.log> or
C<some_nickname.log> in the supplied path. It tries to detect UTF-8 encoding of
every message or else falls back to CP1252, like irssi (and, supposedly, mIRC)
does by default. Resulting log files will be UTF-8 encoded. The default log
format is similar to xchat's, except that it's sane and parsable.

This plugin requires the IRC component to be L<POE::Component::IRC::State|POE::Component::IRC::State>
or a subclass thereof. It also requires a L<POE::Component::IRC::Plugin::BotTraffic|POE::Component::IRC::Plugin::BotTraffic>
to be in the plugin pipeline. It will be added automatically if it is not
present.

=head1 METHODS

=head2 C<new>

Arguments:

'Path', the place where you want the logs saved.

'Private', whether or not to log private messages. Defaults to 1.

'Public', whether or not to log public messages. Defaults to 1.

'Sort_by_date', whether or not to split log files by date, i.e.
F<#channel/YYYY-MM-DD.log> instead of F<#channel.log>. If enabled, the date
will be omitted from the timestamp. Defaults to 0.

'Strip_color', whether or not to strip all color codes from messages. Defaults
to 0.

'Strip_formatting', whether or not to strip all formatting codes from messages.
Defaults to 0.

'Restricted', set this to 1 if you want to all directories/files to be created
without read permissions for other users (i.e. 700 for dirs and 600 for files).
Defaults to 0.

'Format', a hash reference representing the log format, if you want to define
your own. See the source for details.

Returns a plugin object suitable for feeding to
L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
