package POE::Component::IRC::Plugin::BotCommand;

use strict;
use warnings;
use POE::Component::IRC::Common qw( parse_user );
use POE::Component::IRC::Plugin qw( :ALL );

our $VERSION = '1.1';

sub new {
    my ($package, %args) = @_;
    
    for my $cmd (keys %{ $args{Commands} }) {
        $args{Commands}->{lc $cmd} = delete $args{Commands}->{$cmd};
    }
    return bless \%args, $package;
}

sub PCI_register {
    my ($self, $irc) = splice @_, 0, 2;
    
    $self->{Addressed} = 1 if !defined $self->{Addressed};
    $self->{Prefix} = '!' if !defined $self->{Prefix};
    $irc->plugin_register( $self, 'SERVER', qw(msg public) );
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_msg {
    my ($self, $irc) = splice @_, 0, 2;
    my $who = parse_user( ${ $_[0] } );
    my $what = ${ $_[2] };
    
    my $cmd;
    if (!(($cmd) = $what =~ /^\s*HELP\s*(\w+)?/i)) {
        return PCI_EAT_NONE;
    }
    
    if (defined $cmd) {
        if (exists $self->{Commands}->{lc $cmd}) {
            my @help_lines = split /\015?\012/, $self->{Commands}->{lc $cmd};
            $irc->yield(notice => $who => $_) for @help_lines;
        }
        else {
            $irc->yield(notice => $who, "Unknown command: $cmd");
            $irc->yield(notice => $who, 'To get a list of commands, do: /msg '
                . $irc->nick_name() . ' help');
        }
    }
    else {
        $irc->yield(notice => $who, 'Commands: ' . join ', ', keys %{ $self->{Commands} });
        $irc->yield(notice => $who, 'You can do: /msg ' . $irc->nick_name() . ' help <command>');
    }
    
    return PCI_EAT_NONE;
}

sub S_public {
    my ($self, $irc) = splice @_, 0, 2;
    my $who = ${ $_[0] };
    my $channel = ${ $_[1] };
    my $what = ${ $_[2] };
    my $me = $irc->nick_name();

    if ($self->{Addressed}) {
        return PCI_EAT_NONE if !(($what) = $what =~ m/^\s*\Q$me\E[\:\,\;\.\~]?\s*(.*)$/);
    }
    else {
        return PCI_EAT_NONE if $what !~ s/^$self->{Prefix}//;
    }

    my ($cmd, $args);
    if (!(($cmd, $args) = $what =~ /^(\w+)(?:\s+(.+))?$/)) {
        return PCI_EAT_NONE;
    }
    
    $cmd = lc $cmd;
    if (exists $self->{Commands}->{$cmd}) {
        $irc->send_event("irc_botcmd_$cmd" => $who, $channel, $args);
    }
    
    return $self->{Eat} ? PCI_EAT_PLUGIN : PCI_EAT_NONE;
}

sub add {
    my ($self, $cmd, $usage) = @_;
    $cmd = lc $cmd;
    return if exists $self->{Commands}->{$cmd};
    $self->{Commands}->{$cmd} = $usage;
    return 1;
}

sub remove {
    my ($self, $cmd) = @_;
    $cmd = lc $cmd;
    return if !exists $self->{Commands}->{$cmd};
    delete $self->{Commands}->{$cmd};
    return 1;
}

sub list {
    my ($self) = @_;
    return %{ $self->{Commands} };
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::BotCommand - A PoCo-IRC plugin which makes it easy
to handle commands issued to your bot.

=head1 SYNOPSIS

 use POE;
 use POE::Component::Client::DNS;
 use POE::Component::IRC;
 use POE::Component::IRC::Plugin::BotCommand;

 my @channels = ('#channel1', '#channel2');
 my $dns = POE::Component::Client::DNS->spawn();
 my $irc = POE::Component::IRC->spawn(
     nick   => 'YourBot',
     server => 'some.irc.server',
 );

 POE::Session->create(
     package_states => [
         main => [ qw(_start irc_001 irc_botcmd_slap irc_botcmd_lookup dns_response) ],
     ],
 );

 $poe_kernel->run();

 sub _start {
     $irc->plugin_add('BotCommand', POE::Component::IRC::Plugin::BotCommand->new(
         Commands => {
             slap   => 'Takes one argument: a nickname to slap.',
             lookup => 'Takes two arguments: a record type (optional), and a host.',
         }
     ));
     $irc->yield(register => qw(001 botcmd_slap botcmd_lookup));
     $irc->yield(connect => { });
 }

 # join some channels
 sub irc_001 {
     $irc->yield(join => $_) for @channels;
     return;
 }

 # the good old slap
 sub irc_botcmd_slap {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($channel, $arg) = @_[ARG1, ARG2];
     $irc->yield(ctcp => $channel, "ACTION slaps $arg");
     return;
 }

 # non-blocking dns lookup
 sub irc_botcmd_lookup {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($channel, $arg) = @_[ARG1, ARG2];
     my ($type, $host) = $arg =~ /^(?:(\w+) )?(\S+)/;
     
     my $res = $dns->resolve(
         event => 'dns_response',
         host => $host,
         type => $type,
         context => {
             channel => $channel,
             nick    => $nick,
         },
     );
     $poe_kernel->yield(dns_response => $res) if $res;
     return;
 }

 sub dns_response {
     my $res = $_[ARG0];
     my @answers = map { $_->rdatastr } $res->{response}->answer() if $res->{response};
     
     $irc->yield(
         'notice',
         $res->{context}->{channel},
         $res->{context}->{nick} . (@answers
             ? ": @answers"
             : ': no answers for "' . $res->{host} . '"')
     );

     return;
 }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::BotCommand is a L<POE::Component::IRC|POE::Component::IRC>
plugin. It provides you with a standard interface to define bot commands and
lets you know when they are issued. Commands are accepted as channel messages.
However, if someone does C</msg YourBot help>, they will receive a list of
available commands, and information on how to use them.

=head1 METHODS

=head2 C<new>

Four optional arguments:

'Commands', a hash reference, with your commands as keys, and usage information
as values. If the usage string contains newlines, the component will send one
message for each line.

'Addressed', requires users to address the bot by name in order
to issue commands. Default is true.

'Prefix', if 'Addressed' is false, all commands must be prefixed with this
string. Default is '!'. You can set it to '' to allow bare commands.

'Eat', set to true to make the plugin hide C<irc_public> events from other
plugins if they contain a valid command. Default is false.

Returns a plugin object suitable for feeding to L<POE::Component::IRC|POE::Component::IRC>'s
plugin_add() method.

=head2 C<add>

Adds a new command. Takes two arguments, the name of the command, and a string
containing its usage information. Returns false if the command has already been
defined, true otherwise.

=head2 C<remove>

Removes a command. Takes one argument, the name of the command. Returns false
if the command wasn't defined to begin with, true otherwise.

=head2 C<list>

Takes no arguments. Returns a list of key/value pairs, the keys being the
command names and the values being the usage strings.

=head1 OUTPUT

=head2 C<irc_botcmd_*>

You will receive an event like this for every valid command issued. E.g. if
'slap' were a valid command, you would receive an C<irc_botcmd_slap> event
every time someone issued that command. ARG0 is the nick!hostmask of the user
who issued the command. ARG1 is the name of the channel in which the command
was issued. If the command was followed by any arguments, ARG2 will be a string
containing them, otherwise ARG2 will be undefined.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=cut
