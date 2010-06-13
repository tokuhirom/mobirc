package AnyEvent::IRC::Client;
use common::sense;

use Scalar::Util qw/weaken/;

use Encode;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::IRC::Util
      qw/prefix_nick decode_ctcp split_prefix
         is_nick_prefix join_prefix encode_ctcp
         split_unicode_string mk_msg/;

use base AnyEvent::IRC::Connection::;

=head1 NAME

AnyEvent::IRC::Client - A highlevel IRC connection

=head1 SYNOPSIS

   use AnyEvent;
   use AnyEvent::IRC::Client;

   my $c = AnyEvent->condvar;

   my $timer;
   my $con = new AnyEvent::IRC::Client;

   $con->reg_cb (connect => sub {
      my ($con, $err) = @_;
      if (defined $err) {
         warn "connect error: $err\n";
         return;
      }
   });
   $con->reg_cb (registered => sub { print "I'm in!\n"; });
   $con->reg_cb (disconnect => sub { print "I'm out!\n"; $c->broadcast });
   $con->reg_cb (
      sent => sub {
         my ($con) = @_;

         if ($_[2] eq 'PRIVMSG') {
            print "Sent message!\n";

            $timer = AnyEvent->timer (
               after => 1,
               cb => sub {
                  undef $timer;
                  $con->disconnect ('done')
               }
            );
         }
      }
   );

   $con->send_srv (
      PRIVMSG => 'elmex',
      "Hello there I'm the cool AnyEvent::IRC test script!"
   );

   $con->connect ("localhost", 6667, { nick => 'testbot' });
   $c->wait;
   $con->disconnect;

=head1 DESCRIPTION

L<AnyEvent::IRC::Client> is a (nearly) highlevel client connection,
that manages all the stuff that noone wants to implement again and again
when handling with IRC. For example it PONGs the server or keeps track
of the users on a channel.

This module also implements the ISUPPORT (command 005) extension of the IRC protocol
(see http://www.irc.org/tech_docs/005.html) and will enable the NAMESX and UHNAMES
extensions when supported by the server.

Also CTCP support is implemented, all CTCP messages will be decoded and events
for them will be generated. You can configure auto-replies to certain CTCP commands
with the C<ctcp_auto_reply> method, or you can generate the replies yourself.

=head2 A NOTE TO CASE MANAGEMENT

The case insensitivity of channel names and nicknames can lead to headaches
when dealing with IRC in an automated client which tracks channels and nicknames.

I tried to preserve the case in all channel and nicknames
AnyEvent::IRC::Client passes to his user. But in the internal
structures I'm using lower case for the channel names.

The returned hash from C<channel_list> for example has the lower case of the
joined channels as keys.

But I tried to preserve the case in all events that are emitted.
Please keep this in mind when handling the events.

For example a user might joins #TeSt and parts #test later.

=head1 EVENTS

The following events are emitted by L<AnyEvent::IRC::Client>.
Use C<reg_cb> as described in L<Object::Event> to register to such an event.

=over 4

=item registered

Emitted when the connection got successfully registered and the end of the MOTD
(IRC command 376 or 422 (No MOTD file found)) was seen, so you can start sending
commands and all ISUPPORT/PROTOCTL handshaking has been done.

=item channel_add => $msg, $channel, @nicks

Emitted when C<@nicks> are added to the channel C<$channel>,
this happens for example when someone JOINs a channel or when you
get a RPL_NAMREPLY (see RFC1459).


C<$msg> is the IRC message hash that as returned by C<parse_irc_msg>.

=item channel_remove => $msg, $channel, @nicks

Emitted when C<@nicks> are removed from the channel C<$channel>,
happens for example when they PART, QUIT or get KICKed.

C<$msg> is the IRC message hash that as returned by C<parse_irc_msg>
or undef if the reason for the removal was a disconnect on our end.

=item channel_change => $msg, $channel, $old_nick, $new_nick, $is_myself

Emitted when a nickname on a channel changes. This is emitted when a NICK
change occurs from C<$old_nick> to C<$new_nick> give the application a chance
to quickly analyze what channels were affected.  C<$is_myself> is true when
yourself was the one who changed the nick.

=item channel_nickmode_update => $channel, $dest

This event is emitted when the (user) mode (eg. op status) of an occupant of
a channel changes. C<$dest> is the nickname on the C<$channel> who's mode was
updated.

=item channel_topic => $channel, $topic, $who

This is emitted when the topic for a channel is discovered. C<$channel>
is the channel for which C<$topic> is the current topic now.
Which is set by C<$who>. C<$who> might be undefined when it's not known
who set the channel topic.

=item ident_change => $nick, $ident

Whenever the user and host of C<$nick> has been determined or a change
happened this event is emitted.

=item join => $nick, $channel, $is_myself

Emitted when C<$nick> enters the channel C<$channel> by JOINing.
C<$is_myself> is true if yourself are the one who JOINs.

=item part => $nick, $channel, $is_myself, $msg

Emitted when C<$nick> PARTs the channel C<$channel>.
C<$is_myself> is true if yourself are the one who PARTs.
C<$msg> is the PART message.

=item part => $kicked_nick, $channel, $is_myself, $msg

Emitted when C<$kicked_nick> is KICKed from the channel C<$channel>.
C<$is_myself> is true if yourself are the one who got KICKed.
C<$msg> is the PART message.

=item nick_change => $old_nick, $new_nick, $is_myself

Emitted when C<$old_nick> is renamed to C<$new_nick>.
C<$is_myself> is true when yourself was the one who changed the nick.

=item away_status_change => $bool

Emitted whenever a presence/away status change for you was detected.
C<$bool> is true if you are now away, or false/undef if you are not
away anymore.

You can change your away status by emitting the C<AWAY> IRC command:

   $cl->send_srv (AWAY => "I'm not here right now");

Or reset it:

   $cl->send_srv ('AWAY');

=item ctcp => $src, $target, $tag, $msg, $type

Emitted when a CTCP message was found in either a NOTICE or PRIVMSG
message. C<$tag> is the CTCP message tag. (eg. "PING", "VERSION", ...).
C<$msg> is the CTCP message and C<$type> is either "NOTICE" or "PRIVMSG".

C<$src> is the source nick the message came from.
C<$target> is the target nickname (yours) or the channel the ctcp was sent
on.

=item "ctcp_$tag", => $src, $target, $msg, $type

Emitted when a CTCP message was found in either a NOTICE or PRIVMSG
message. C<$tag> is the CTCP message tag (in lower case). (eg. "ping", "version", ...).
C<$msg> is the CTCP message and C<$type> is either "NOTICE" or "PRIVMSG".

C<$src> is the source nick the message came from.
C<$target> is the target nickname (yours) or the channel the ctcp was sent
on.

=item dcc_ready => $id, $dest, $type, $local_ip, $local_port

Whenever a locally initiated DCC request is made this event is emitted
after the listening socket has been setup.

C<$id> is the DCC connection ID.

C<$dest> and C<$type> are the destination and type of the DCC request.

C<$local_ip> is the C<$local_ip> argument passed to C<start_dcc> or
the IP the socket is bound to.

C<$local_port> is the TCP port is the socket is listening on.

=item dcc_request => $id, $src, $type, $arg, $addr, $port

Whenever we receive a DCC offer from someone else this event is emitted.
C<$id> is the DCC connection ID, C<$src> is his nickname, C<$type> is the DCC
type in lower cases (eg. 'chat').  C<$arg> is the DCC type argument. C<$addr>
is the IP address we can reach him at in ASCII encoded human readable form (eg.
something like "127.0.0.1").  And C<$port> is the TCP port we have to connect
to.

To answer to his request you can just call C<dcc_accept> with the C<$id>.

=item dcc_accepted => $id, $type, $hdl

When the locally listening DCC socket has received a connection this event is emitted.

C<$id> and C<$type> are the DCC connection ID and type of the DCC request.

C<$hdl> is a pre-configured L<AnyEvent::Handle> object, which you only
need to care about in case you want to implement your own DCC protocol.
(This event has the on_error and on_eof events pre-configured to cleanup
the data structures in this connection).

=item dcc_connected => $id, $type, $hdl

Whenever we accepted a DCC offer and connected by using C<dcc_accept> this
event is emitted. C<$id> is the DCC connection ID.  C<$type> is the dcc type in
lower case. C<$hdl> is the L<AnyEvent::Handle> object of the connection (see
also C<dcc_accepted> above).

=item dcc_close => $id, $type, $reason

This event is emitted whenever a DCC connection is terminated.

C<$id> and C<$type> are the DCC connection ID and type of the DCC request.

C<$reason> is a human readable string indicating the reason for the end of
the DCC request.

=item dcc_chat_msg => $id, $msg

This event is emitted for a DCC CHAT message. C<$id> is the DCC connection
ID we received the message on. And C<$msg> is the message he sent us.

=item quit => $nick, $msg

Emitted when the nickname C<$nick> QUITs with the message C<$msg>.

=item publicmsg => $channel, $ircmsg

Emitted for NOTICE and PRIVMSG where the target C<$channel> is a channel.
C<$ircmsg> is the original IRC message hash like it is returned by C<parse_irc_msg>.

The last parameter of the C<$ircmsg> will have all CTCP messages stripped off.

=item privatemsg => $nick, $ircmsg

Emitted for NOTICE and PRIVMSG where the target C<$nick> (most of the time you) is a nick.
C<$ircmsg> is the original IRC message hash like it is returned by C<parse_irc_msg>.

The last parameter of the C<$ircmsg> will have all CTCP messages stripped off.

=item error => $code, $message, $ircmsg

Emitted when any error occurs. C<$code> is the 3 digit error id string from RFC
1459 or the string 'ERROR'. C<$message> is a description of the error.
C<$ircmsg> is the complete error irc message.

You may use AnyEvent::IRC::Util::rfc_code_to_name to convert C<$code> to the error
name from the RFC 2812. eg.:

   rfc_code_to_name ('471') => 'ERR_CHANNELISFULL'

NOTE: This event is also emitted when a 'ERROR' message is received.

=item debug_send => $command, @params

Is emitted everytime some command is sent.

=item debug_recv => $ircmsg

Is emitted everytime some command was received.

=back

=head1 METHODS

=over 4

=item $cl = AnyEvent::IRC::Client->new (%args)

This is the constructor of a L<AnyEvent::IRC::Client> object,
which stands logically for a client connected to ONE IRC server.
You can reuse it and call C<connect> once it disconnected.

B<NOTE:> You are free to use the hash member C<heap> to store any associated
data with this object. For example retry timers or anything else.

C<%args> may contain these options:

=over 4

=item send_initial_whois => $bool

If this option is enabled an initial C<WHOIS> command is sent to your own
NICKNAME to determine your own I<ident>. See also the method C<nick_ident>.
This is necessary to ensure that the information about your own nickname
is available as early as possible for the C<send_long_message> method.

C<$bool> is C<false> by default.

=back

=cut

my %LOWER_CASEMAP = (
   rfc1459          => sub { tr/A-Z[]\\\^/a-z{}|~/ },
   'strict-rfc1459' => sub { tr/A-Z[]\\/a-z{}|/ },
   ascii            => sub { tr/A-Z/a-z/ },
);

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = $class->SUPER::new (@_);

   $self->reg_cb (irc_376     => \&welcome_cb);
   $self->reg_cb (irc_422     => \&welcome_cb);
   $self->reg_cb (irc_005     => \&isupport_cb);
   $self->reg_cb (irc_join    => \&join_cb);
   $self->reg_cb (irc_nick    => \&nick_cb);
   $self->reg_cb (irc_part    => \&part_cb);
   $self->reg_cb (irc_kick    => \&kick_cb);
   $self->reg_cb (irc_quit    => \&quit_cb);
   $self->reg_cb (irc_mode    => \&mode_cb);
   $self->reg_cb (irc_353     => \&namereply_cb);
   $self->reg_cb (irc_366     => \&endofnames_cb);
   $self->reg_cb (irc_352     => \&whoreply_cb);
   $self->reg_cb (irc_311     => \&whoisuser_cb);
   $self->reg_cb (irc_305     => \&away_change_cb);
   $self->reg_cb (irc_306     => \&away_change_cb);
   $self->reg_cb (irc_ping    => \&ping_cb);
   $self->reg_cb (irc_pong    => \&pong_cb);

   $self->reg_cb (irc_privmsg => \&privmsg_cb);
   $self->reg_cb (irc_notice  => \&privmsg_cb);

   $self->reg_cb ('irc_*'     => \&debug_cb);
   $self->reg_cb ('irc_*'     => \&anymsg_cb);
   $self->reg_cb ('irc_*'     => \&update_ident_cb);

   $self->reg_cb (disconnect  => \&disconnect_cb);

   $self->reg_cb (irc_332     => \&rpl_topic_cb);
   $self->reg_cb (irc_topic   => \&topic_change_cb);

   $self->reg_cb (ctcp        => \&ctcp_auto_reply_cb);

   $self->reg_cb (registered  => \&registered_cb);

   $self->reg_cb (nick_change => \&update_ident_nick_change_cb);

   $self->{def_nick_change} = $self->{nick_change} =
      sub {
         my ($old_nick) = @_;
         "${old_nick}_"
      };

   $self->_setup_internal_dcc_handlers;

   $self->cleanup;

   return $self;
}

sub cleanup {
   my ($self) = @_;

   $self->{channel_list}  = { };
   $self->{isupport}      = { };
   $self->{casemap_func}  = $LOWER_CASEMAP{rfc1459};
   $self->{prefix_chars}  = '@+';
   $self->{prefix2mode}   = { '@' => 'o', '+' => 'v' };
   $self->{channel_chars} = '#&';

   $self->{change_nick_cb_guard} =
      $self->reg_cb (
         irc_437 => \&change_nick_login_cb,
         irc_433 => \&change_nick_login_cb,
      );

   delete $self->{away_status};
   delete $self->{dcc};
   delete $self->{dcc_id};
   delete $self->{_tmp_namereply};
   delete $self->{last_pong_recv};
   delete $self->{last_ping_sent};
   delete $self->{_ping_timer};
   delete $self->{con_queue};
   delete $self->{chan_queue};
   delete $self->{registered};
   delete $self->{idents};
   delete $self->{nick};
   delete $self->{user};
   delete $self->{real};
   delete $self->{server_pass};
   delete $self->{register_cb_guard};
}

=item $cl->connect ($host, $port)

=item $cl->connect ($host, $port, $info)

This method does the same as the C<connect> method of L<AnyEvent::Connection>,
but if the C<$info> parameter is passed it will automatically register with the
IRC server upon connect for you, and you won't have to call the C<register>
method yourself.

The keys of the hash reference you can pass in C<$info> are:

   nick      - the nickname you want to register as
   user      - your username
   real      - your realname
   password  - the server password
   timeout   - the TCP connect timeout

All keys, except C<nick> are optional.

=cut

sub connect {
   my ($self, $host, $port, $info) = @_;

   if (defined $info) {
      $self->{register_cb_guard} = $self->reg_cb (
         ext_before_connect => sub {
            my ($self, $err) = @_;

            unless ($err) {
               $self->register (
                  $info->{nick}, $info->{user}, $info->{real}, $info->{password}
               );
            }

            delete $self->{register_cb_guard};
         }
      );
   }

   $self->SUPER::connect ($host, $port, $info->{timeout});
}

=item $cl->register ($nick, $user, $real, $server_pass)

Sends the IRC registration commands NICK and USER.
If C<$server_pass> is passed also a PASS command is generated.

NOTE: If you passed the nick, user, etc. already to the C<connect> method
you won't need to call this method, as L<AnyEvent::IRC::Client> will do that
for you.

=cut

sub register {
   my ($self, $nick, $user, $real, $pass) = @_;

   $self->{nick} = $nick;
   $self->{user} = $user;
   $self->{real} = $real;
   $self->{server_pass} = $pass;

   $self->send_msg ("PASS", $pass) if defined $pass;
   $self->send_msg ("NICK", $nick);
   $self->send_msg ("USER", $user || $nick, "*", "0", $real || $nick);
}

=item $cl->set_nick_change_cb ($callback)

This method lets you modify the nickname renaming mechanism when registering
the connection. C<$callback> is called with the current nickname as first
argument when a ERR_NICKNAMEINUSE or ERR_UNAVAILRESOURCE error occurs on login.
The return value of C<$callback> will then be used to change the nickname.

If C<$callback> is not defined the default nick change callback will be used
again.

The default callback appends '_' to the end of the nickname supplied in the
C<register> routine.

If the callback returns the same nickname that was given it the connection
will be terminated.

=cut

sub set_nick_change_cb {
   my ($self, $cb) = @_;
   $cb = $self->{def_nick_change} unless defined $cb;
   $self->{nick_change} = $cb;
}

=item $cl->nick ()

Returns the current nickname, under which this connection
is registered at the IRC server. It might be different from the
one that was passed to C<register> as a nick-collision might happened
on login.

=cut

sub nick { $_[0]->{nick} }

=item $cl->is_my_nick ($string)

This returns true if C<$string> is the nick of ourself.

=cut

sub is_my_nick {
   my ($self, $string) = @_;
   $self->eq_str ($string, $self->nick);
}

=item $cl->registered ()

Returns a true value when the connection has been registered successful and
you can send commands.

=cut

sub registered { $_[0]->{registered} }

=item $cl->channel_list ()

=item $cl->channel_list ($channel)

Without C<$channel> parameter: This returns a hash reference. The keys are the
currently joined channels in lower case.  The values are hash references which
contain the joined nicks as key (NOT in lower case!) and the nick modes as
values (as returned from C<nick_modes ()>).

If the C<$channel> parameter is given it returns the hash reference of the channel
occupants or undef if the channel does not exist.

=cut

sub channel_list {
   my ($self, $chan) = @_;

   if (defined $chan) {
      return $self->{channel_list}->{$self->lower_case ($chan)}
   } else {
      return $self->{channel_list} || {};
   }
}

=item $cl->nick_modes ($channel, $nick)

This returns the mode map of the C<$nick> on C<$channel>.
Returns undef if the channel isn't joined or the user is not on it.
Returns a hash reference with the modes the user has as keys and 1's as values.

=cut

sub nick_modes {
    my ($self, $channel, $nick) = @_;

    my $c = $self->channel_list ($channel)
       or return undef;

    my (%lcc) = map { $self->lower_case ($_) => $c->{$_} } keys %$c;
    return $lcc{$self->lower_case ($nick)};
}

=item $cl->send_msg (...)

See also L<AnyEvent::IRC::Connection>.

=cut

sub send_msg {
   my ($self, @a) = @_;
   $self->event (debug_send => @a);
   $self->SUPER::send_msg (@a);
}

=item $cl->send_srv ($command, @params)

This function sends an IRC message that is constructed by C<mk_msg (undef,
$command, @params)> (see L<AnyEvent::IRC::Util>). If the C<registered> event
has NOT yet been emitted the messages are queued until that event is emitted,
and then sent to the server.

B<NOTE:> If you stop the registered event (with C<stop_event>, see L<Object::Event>)
in a callback registered to the C<before_registered> event, the C<send_srv> queue
will B<NOT> be flushed and B<NOT> sent to the server!

This allows you to simply write this:

   my $cl = AnyEvent::IRC::Client->new;
   $cl->connect ('irc.freenode.net', 6667, { nick => 'testbot' });
   $cl->send_srv (PRIVMSG => 'elmex', 'Hi there!');

Instead of:

   my $cl = AnyEvent::IRC::Client->new;
   $cl->reg_cb (
      registered => sub {
         $cl->send_msg (PRIVMSG => 'elmex', 'Hi there!');
      }
   );
   $cl->connect ('irc.freenode.net', 6667, { nick => 'testbot' });

=cut

sub send_srv {
   my ($self, @msg) = @_;

   if ($self->registered) {
      $self->send_msg (@msg);

   } else {
      push @{$self->{con_queue}}, \@msg;
   }
}

=item $cl->clear_srv_queue ()

Clears the server send queue.

=cut

sub clear_srv_queue {
   my ($self) = @_;
   $self->{con_queue} = [];
}


=item $cl->send_chan ($channel, $command, @params)

This function sends a message (constructed by C<mk_msg (undef, $command,
@params)> to the server, like C<send_srv> only that it will queue
the messages if it hasn't joined the channel C<$channel> yet. The queued
messages will be send once the connection successfully JOINed the C<$channel>.

C<$channel> will be lowercased so that any case that comes from the server matches.
(Yes, IRC handles upper and lower case as equal :-(

Be careful with this, there are chances you might not join the channel you
wanted to join. You may wanted to join #bla and the server redirects that
and sends you that you joined #blubb. You may use C<clear_chan_queue> to
remove the queue after some timeout after joining, so that you don't end up
with a memory leak.

=cut

sub send_chan {
   my ($self, $chan, @msg) = @_;

   if ($self->{channel_list}->{$self->lower_case ($chan)}) {
      $self->send_msg (@msg);

   } else {
      push @{$self->{chan_queue}->{$self->lower_case ($chan)}}, \@msg;
   }
}

=item $cl->clear_chan_queue ($channel)

Clears the channel queue of the channel C<$channel>.

=cut

sub clear_chan_queue {
   my ($self, $chan) = @_;
   $self->{chan_queue}->{$self->lower_case ($chan)} = [];
}

=item my (@lines) = $cl->send_long_message ($encoding, $overhead, $cmd, @params, $msg)

As IRC only allows 512 byte blocks of messages and sometimes
your messages might get longer, you have a problem. This method
will solve your problem:

This method can be used to split up long messages into multiple
commands.

C<$cmd> and C<@params> are the IRC command and it's first parameters,
except the last one: the C<$msg>. C<$msg> can be a Unicode string,
which will be encoded in C<$encoding> before sending.

If you want to send a CTCP message you can encode it in the C<$cmd> by
appending the CTCP command with a C<"\001">. For example if you want to
send a CTCP ACTION you have to give this C<$cmd>:

   $cl->send_long_message (undef, 0, "PRIVMSG\001ACTION", "#test", "rofls");

C<$encoding> can be undef if you don't need any recoding of C<$msg>.
But in case you want to send Unicode it is necessary to determine where
to split a message exactly, to not break the encoding.

Please also note that the C<nick_ident> for your own nick is necessary to
compute this. To ensure best performance as possible use the
C<send_initial_whois> option if you want to use this method.

But note that this method might not work 100% correct and you might still get
at least partially chopped off lines if you use C<send_long_message> before the
C<WHOIS> reply to C<send_initial_whois> arrived.

To be on the safest side you might want to wait until that initial C<WHOIS>
reply arrived.

The return value of this method is the list of the actually sent lines (but
without encoding applied).

=cut

sub send_long_message {
   my ($self, $encoding, $overhead, $cmd, @params) = @_;
   my $msg = pop @params;

   my $ctcp;
   ($cmd, $ctcp) = split /\001/, $cmd;

   my $id = $self->nick_ident ($self->nick);
   if ($id eq '') {
      $id = "X" x 60; # just in case the ident is not available...
   }

   my $init_len = length mk_msg ($id, $cmd, @params, " "); # i know off by 1

   if ($ctcp ne '') {
      $init_len += length ($ctcp) + 3; # CTCP cmd + " " + "\001" x 2
   }

   my $max_len = 500; # give 10 bytes extra margin

   my $line_len = $max_len - $init_len;

   # split up the multiple lines in the message:
   my @lines = split /\n/, $msg;

   # splitup long lines into multiple ones:
   @lines =
      map split_unicode_string ($encoding, $_, $line_len), @lines;

   # send lines line-by-line:
   for my $line (@lines) {
      my $smsg = encode ($encoding, $line);

      if ($ctcp ne '') {
         $smsg = encode_ctcp ([$ctcp, $smsg])
      }

      $self->send_srv ($cmd => @params, $smsg);
   }

   @lines
}

=item $cl->enable_ping ($interval, $cb)

This method enables a periodical ping to the server with an interval of
C<$interval> seconds. If no PONG was received from the server until the next
interval the connection will be terminated or the callback in C<$cb> will be called.

(C<$cb> will have the connection object as it's first argument.)

Make sure you call this method after the connection has been established.
(eg. in the callback for the C<registered> event).

=cut

sub enable_ping {
   my ($self, $int, $cb) = @_;

   $self->{last_pong_recv} = 0;
   $self->{last_ping_sent} = time;

   $self->send_srv (PING => "AnyEvent::IRC");

   $self->{_ping_timer} =
      AE::timer $int, 0, sub {
         if ($self->{last_pong_recv} < $self->{last_ping_sent}) {
            delete $self->{_ping_timer};
            if ($cb) {
               $cb->($self);
            } else {
               $self->disconnect ("Server timeout");
            }

         } else {
            $self->enable_ping ($int, $cb);
         }
      };
}

=item $cl->lower_case ($str)

Converts the given string to lowercase according to CASEMAPPING setting given by
the IRC server. If none was sent, the default - rfc1459 - will be used.

=cut

sub lower_case {
   my($self, $str) = @_;
   local $_ = $str;
   $self->{casemap_func}->();
   return $_;
}

=item $cl->eq_str ($str1, $str2)

This function compares two strings, whether they are describing the same
IRC entity. They are lower cased by the networks case rules and compared then.

=cut

sub eq_str {
   my ($self, $a, $b) = @_;
   $self->lower_case ($a) eq $self->lower_case ($b)
}

=item $cl->isupport ()

=item $cl->isupport ($key)

Provides access to the ISUPPORT variables sent by the IRC server. If $key is
given this method will return its value only, otherwise a hashref with all values
is returned

=cut

sub isupport {
   my($self, $key) = @_;
   if (defined ($key)) {
      return $self->{isupport}->{$key};
   } else {
      return $self->{isupport};
   }
}

=item $cl->split_nick_mode ($prefixed_nick)

This method splits the C<$prefix_nick> (eg. '+elmex') up into the
mode of the user and the nickname.

This method returns 2 values: the mode map and the nickname.

The mode map is a hash reference with the keys being the modes the nick has set
and the values being 1.

NOTE: If you feed in a prefixed ident ('@elmex!elmex@fofofof.de') you get 3 values
out actually: the mode map, the nickname and the ident, otherwise the 3rd value is undef.

=cut

sub split_nick_mode {
   my ($self, $prefixed_nick) = @_;

   my $pchrs = $self->{prefix_chars};

   my %mode_map;

   my $nick;

   if ($prefixed_nick =~ /^([\Q$pchrs\E]+)(.+)$/) {
      my $p = $1;
      $nick = $2;
      for (split //, $p) { $mode_map{$self->map_prefix_to_mode ($_)} = 1 }
   } else {
      $nick = $prefixed_nick;
   }

   my (@n) = split_prefix ($nick);

   if (@n > 1 && defined $n[1]) {
      return (\%mode_map, $n[0], $nick);
   } else {
      return (\%mode_map, $nick, undef);
   }
}

=item $cl->map_prefix_to_mode ($prefix)

Maps the nick prefix (eg. '@') to the corresponding mode (eg. 'o').
Returns undef if no such prefix exists (on the connected server).

=cut

sub map_prefix_to_mode {
   my ($self, $prefix) = @_;
   $self->{prefix2mode}->{$prefix}
}

=item $cl->map_mode_to_prefix ($mode)

Maps the nick mode (eg. 'o') to the corresponding prefix (eg. '@').
Returns undef if no such mode exists (on the connected server).

=cut

sub map_mode_to_prefix {
   my ($self, $mode) = @_;
   for (keys %{$self->{prefix2mode}}) {
      return $_ if $self->{prefix2mode}->{$_} eq $mode;
   }

   return undef;
}

=item $cl->available_nick_modes ()

Returns a list of possible modes on this IRC server. (eg. 'o' for op).

=cut

sub available_nick_modes {
   my ($self) = @_;
   map { $self->map_prefix_to_mode ($_) } split //, $self->{prefix_chars}
}

=item $cl->is_channel_name ($string)

This return true if C<$string> is a channel name. It analyzes the prefix
of the string (eg. if it is '#') and returns true if it finds a channel prefix.
Those prefixes might be server specific, so ISUPPORT is checked for that too.

=cut

sub is_channel_name {
   my ($self, $string) = @_;

   my $cchrs = $self->{channel_chars};
   $string =~ /^([\Q$cchrs\E]+)(.+)$/;
}

=item $cl->nick_ident ($nick)

This method returns the whole ident of the C<$nick> if the informations is available.
If the nick's ident hasn't been seen yet, undef is returned.

B<NOTE:> If you want to rely on the C<nick_ident> of your own nick you should
make sure to enable the C<send_initial_whois> option in the constructor.

=cut

sub nick_ident {
   my ($self, $nick) = @_;
   $self->{idents}->{$self->lower_case ($nick)}
}

=item my $bool = $cl->away_status

Returns a true value if you are away or undef if you are not away.

=cut

sub away_status { $_[0]->{away_status} }

=item $cl->ctcp_auto_reply ($ctcp_command, @msg)

=item $cl->ctcp_auto_reply ($ctcp_command, $coderef)

This method installs an auto-reply for the reception of the C<$ctcp_command>
via PRIVMSG, C<@msg> will be used as argument to the C<encode_ctcp> function of
the L<AnyEvent::IRC::Util> package. The replies will be sent with the NOTICE
IRC command.

If C<$coderef> was given and is a code reference, it will called each time a
C<$ctcp_command> is received, this is useful for eg.  CTCP PING reply
generation. The arguments will be the same arguments that the C<ctcp> event
callbacks get. (See also C<ctcp> event description above).  The return value of
the called subroutine should be a list of arguments for C<encode_ctcp>.

Currently you can only configure one auto-reply per C<$ctcp_command>.

Example:

   $cl->ctcp_auto_reply ('VERSION', ['VERSION', 'ScriptBla:0.1:Perl']);

   $cl->ctcp_auto_reply ('PING', sub {
      my ($cl, $src, $target, $tag, $msg, $type) = @_;
      ['PING', $msg]
   });

=cut

sub ctcp_auto_reply {
   my ($self, $ctcp_command, @msg) = @_;

   $self->{ctcp_auto_replies}->{$ctcp_command} = \@msg;
}

sub _setup_internal_dcc_handlers {
   my ($self) = @_;

   $self->reg_cb (ctcp_dcc => sub {
      my ($self, $src, $target, $msg, $type) = @_;

      if ($self->is_my_nick ($target)) {
         my ($dcc_type, $arg, $addr, $port) = split /\x20/, $msg;

         $dcc_type = lc $dcc_type;

         if ($dcc_type eq 'send') {
            if ($msg =~ /SEND (.*?) (\d+) (\d+)/) {
               ($arg, $addr, $port) = ($1, $2, $3);
               $arg =~ s/^\"(.*)\"$/\1/;
            }
         }

         $addr = format_address (pack "N", $addr);

         my $id = ++$self->{dcc_id};

         $self->{dcc}->{$id} = {
            type => lc ($dcc_type),
            dest => $self->lower_case ($src),
            ip   => $addr,
            port => $port,
            arg  => $arg,
         };

         $self->event (dcc_request => $id, $src, $dcc_type, $arg, $addr, $port);
      }
   });

   $self->reg_cb (dcc_ready => sub {
      my ($self, $id, $dest, $type, $local_ip, $local_port) = @_;

      $local_ip = unpack ("N", parse_address ($local_ip));

      if ($type eq 'chat') {
         $self->send_msg (
            PRIVMSG => $dest,
            encode_ctcp ([DCC => "CHAT", "CHAT", $local_ip, $local_port]));

      } elsif ($type eq 'send') {
         $self->send_msg (
            PRIVMSG => $dest,
            encode_ctcp ([DCC => "SEND", "NOTHING", $local_ip, $local_port]));
      }
   });

   $self->reg_cb (dcc_accepted => sub {
      my ($self, $id, $type, $hdl) = @_;

      if ($type eq 'chat') {
         $hdl->on_read (sub {
            my ($hdl) = @_;

            $hdl->push_read (line => sub {
               my ($hdl, $line) = @_;
               $self->event (dcc_chat_msg => $id, $line);
            });
         });
      }
   });

   $self->reg_cb (dcc_connected => sub {
      my ($self, $id, $type, $hdl) = @_;

      if ($type eq 'chat') {
         $hdl->on_read (sub {
            my ($hdl) = @_;

            $hdl->push_read (line => sub {
               my ($hdl, $line) = @_;
               $self->event (dcc_chat_msg => $id, $line);
            });
         });
      }
   });
}

=item $cl->dcc_initiate ($dest, $type, $timeout, $local_ip, $local_port)

This function will initiate a DCC TCP connection to C<$dest> of type C<$type>.
It will setup a listening TCP socket on C<$local_port>, or a random port if
C<$local_port> is undefined. C<$local_ip> is the IP that is being sent to the
receiver of the DCC connection. If it is undef the local socket will be bound
to 0 (or "::" in case of IPv6) and C<$local_ip> will probably be something like
"0.0.0.0". It is always advisable to set C<$local_ip> to a (from the "outside",
what ever that might be) reachable IP Address.

C<$timeout> is the time in seconds after which the listening socket will be
closed if the receiver didn't connect yet. The default is 300 (5 minutes).

When the local listening socket has been setup the C<dcc_ready> event is
emitted.  When the receiver connects to the socket the C<dcc_accepted> event is
emitted.  And whenever a dcc connection is closed the C<dcc_close> event is
emitted.

For canceling the DCC offer or closing the connection see C<dcc_disconnect> below.

The return value of this function will be the ID of the initiated DCC connection,
which can be used for functions such as C<dcc_disconnect>, C<send_dcc_chat> or
C<dcc_handle>.

=cut

sub dcc_initiate {
   my ($self, $dest, $type, $timeout, $local_ip, $local_port) = @_;

   $dest = $self->lower_case ($dest);
   $type = lc $type;

   my $id = ++$self->{dcc_id};
   my $dcc = $self->{dcc}->{$id} = { id => $id, type => $type, dest => $dest };

   weaken $dcc;
   weaken $self;

   $dcc->{timeout} = AnyEvent->timer (after => $timeout || 5 * 60, cb => sub {
      $self->dcc_disconnect ($id, "TIMEOUT") if $self;
   });

   $dcc->{listener} = tcp_server undef, $local_port, sub {
      my ($fh, $h, $p) = @_;
      return unless $dcc && $self;

      $dcc->{handle} = AnyEvent::Handle->new (
         fh => $fh,
         on_eof => sub {
            $self->dcc_disconnect ($id, "EOF");
         },
         on_error => sub {
            $self->dcc_disconnect ($id, "ERROR: $!");
         }
      );

      $self->event (dcc_accepted => $id, $type, $dcc->{handle});

      delete $dcc->{listener};
      delete $dcc->{timeout};

   }, sub {
      my ($fh, $host, $port) = @_;
      return unless $dcc && $self;

      $local_ip   = $host unless defined $local_ip;
      $local_port = $port;

      $dcc->{local_ip}   = $local_ip;
      $dcc->{local_port} = $local_port;

      $self->event (dcc_ready => $id, $dest, $type, $local_ip, $local_port);
   };

   $id
}


=item $cl->dcc_disconnect ($id, $reason)

In case you want to withdraw a DCC offer sent by C<start_dcc> or close
a DCC connection you call this function.

C<$id> is the DCC connection ID.  C<$reason> should be a human readable reason
why you ended the dcc offer, but it's only used for local logging purposes (see
C<dcc_close> event).

=cut

sub dcc_disconnect {
   my ($self, $id, $reason) = @_;

   if (my $dcc = delete $self->{dcc}->{$id}) {
      delete $dcc->{handle};
      $self->event (dcc_close => $id, $dcc->{type}, $reason);
   }
}

=item $cl->dcc_accept ($id, $timeout)

This will accept an incoming DCC request as received by the C<dcc_request>
event. The C<dcc_connected> event will be emitted when we successfully
connected. And the C<dcc_close> event when the connection was disconnected.

C<$timeout> is the connection try timeout in seconds. The default is 300 (5 minutes).

=cut

sub dcc_accept {
   my ($self, $id, $timeout) = @_;

   my $dcc = $self->{dcc}->{$id}
      or return;

   weaken $dcc;
   weaken $self;

   $dcc->{timeout} = AnyEvent->timer (after => $timeout || 5 * 60, cb => sub {
      $self->dcc_disconnect ($id, "CONNECT TIMEOUT") if $self;
   });

   $dcc->{connect} = tcp_connect $dcc->{ip}, $dcc->{port}, sub {
      my ($fh) = @_;
      return unless $dcc && $self;

      delete $dcc->{timeout};
      delete $dcc->{connect};

      unless ($fh) {
         $self->dcc_disconnect ($id, "CONNECT ERROR: $!");
         return;
      }

      $dcc->{handle} = AnyEvent::Handle->new (
         fh => $fh,
         on_eof => sub {
            delete $dcc->{handle};
            $self->dcc_disconnect ($id, "EOF");
         },
         on_error => sub {
            delete $dcc->{handle};
            $self->dcc_disconnect ($id, "ERROR: $!");
         }
      );

      $self->event (dcc_connected => $id, $dcc->{type}, $dcc->{handle});
   };

   $id
}

sub dcc_handle {
   my ($self, $id) = @_;

   if (my $dcc = $self->{dcc}->{$id}) {
      return $dcc->{handle}
   }
   return;
}

sub send_dcc_chat {
   my ($self, $id, $msg) = @_;

   if (my $dcc = $self->{dcc}->{$id}) {
      if ($dcc->{handle}) {
         $dcc->{handle}->push_write ("$msg\015\012");
      }
   }
}

################################################################################
# Private utility functions
################################################################################

sub _was_me {
   my ($self, $msg) = @_;
   $self->lower_case (prefix_nick ($msg)) eq $self->lower_case ($self->nick ())
}

sub update_ident {
   my ($self, $ident) = @_;
   my ($n, $u, $h) = split_prefix ($ident);
   my $old = $self->{idents}->{$self->lower_case ($n)};
   $self->{idents}->{$self->lower_case ($n)} = $ident;
   if ($old ne $ident) {
      $self->event (ident_change => $n, $ident);
   }
   #d# warn "IDENTS:\n".(join "\n", map { "\t$_\t=>\t$self->{idents}->{$_}" } keys %{$self->{idents}})."\n";
}

################################################################################
# Channel utility functions
################################################################################

sub channel_remove {
   my ($self, $msg, $chan, $nicks) = @_;

   for my $nick (@$nicks) {
      if ($self->lower_case ($nick) eq $self->lower_case ($self->nick ())) {
         delete $self->{chan_queue}->{$self->lower_case ($chan)};
         delete $self->{channel_list}->{$self->lower_case ($chan)};
         last;
      } else {
         delete $self->{channel_list}->{$self->lower_case ($chan)}->{$nick};
      }
   }
}

sub channel_add {
   my ($self, $msg, $chan, $nicks, $modes) = @_;

   my @mods = @$modes;

   for my $nick (@$nicks) {
      my $mode = shift @mods;

      if ($self->is_my_nick ($nick)) {
         for (@{$self->{chan_queue}->{$self->lower_case ($chan)}}) {
            $self->send_msg (@$_);
         }

         $self->clear_chan_queue ($chan);
      }

      my $ch = $self->{channel_list}->{$self->lower_case ($chan)} ||= { };

      if (defined $mode) {
         $ch->{$nick} = $mode;
         $self->event (channel_nickmode_update => $chan, $nick);
      } else {
         $ch->{$nick} = { } unless defined $ch->{$nick};
      }
   }
}

sub channel_mode_change {
   my ($self, $chan, $op, $mode, $nick) = @_;

   my $nickmode = $self->nick_modes ($chan, $nick);
   defined $nickmode or return;

   $op eq '+'
      ? $nickmode->{$mode} = 1
      : delete $nickmode->{$mode};
}

sub _filter_new_nicks_from_channel {
   my ($self, $chan, @nicks) = @_;
   grep { not exists $self->{channel_list}->{$self->lower_case ($chan)}->{$_} } @nicks;
}

################################################################################
# Callbacks
################################################################################

sub anymsg_cb {
   my ($self, $msg) = @_;

   my $cmd = lc $msg->{command};

   if ($cmd =~ /^\d\d\d$/ && not ($cmd >= 400 && $cmd <= 599)) {
      $self->event (statmsg => $msg);
   } elsif (($cmd >= 400 && $cmd <= 599) || $cmd eq 'error') {
      $self->event (error => $msg->{command}, $msg->{params}->[-1], $msg);
   }
}

sub privmsg_cb {
   my ($self, $msg) = @_;

   my ($trail, $ctcp) = decode_ctcp ($msg->{params}->[-1]);

   for (@$ctcp) {
      $self->event (ctcp => prefix_nick ($msg), $msg->{params}->[0], $_->[0], $_->[1], $msg->{command});
      $self->event ("ctcp_".lc ($_->[0]), prefix_nick ($msg), $msg->{params}->[0], $_->[1], $msg->{command});
   }

   $msg->{params}->[-1] = $trail;

   if ($msg->{params}->[-1] ne '') {
      my $targ = $msg->{params}->[0];
      if ($self->is_channel_name ($targ)) {
         $self->event (publicmsg => $targ, $msg);

      } else {
         $self->event (privatemsg => $targ, $msg);
      }
   }
}

sub welcome_cb {
   my ($self, $msg) = @_;

   if ($self->{registered}) {
      return;
   }

   $self->{registered} = 1;
   $self->event ('registered');
}

sub registered_cb {
   my ($self, $msg) = @_;

   $self->send_srv (WHOIS => $self->nick)
      if $self->{send_initial_whois};

   for (@{$self->{con_queue}}) {
      $self->send_msg (@$_);
   }
   $self->clear_srv_queue ();
}

sub isupport_cb {
   my ($self, $msg) = @_;

   foreach (@{$msg->{params}}) {
      if (/([A-Z]+)(?:=(.+))?/) {
         $self->{isupport}->{$1} = defined $2 ? $2 : 1;
      }
   }

   if (defined (my $casemap = $self->{isupport}->{CASEMAPPING})) {
      if (defined (my $func = $LOWER_CASEMAP{$casemap})) {
         $self->{casemap_func} = $func;
      } else {
         $self->{casemap_func} = $LOWER_CASEMAP{rfc1459};
      }
   }

   if (defined (my $nick_prefixes = $self->{isupport}->{PREFIX})) {
      if ($nick_prefixes =~ /^\(([^)]+)\)(.+)$/) {
         my ($modes, $prefixes) = ($1, $2);
         $self->{prefix_chars} = $prefixes;
         my @prefixes = split //, $prefixes;
         $self->{prefix2mode} = { };
         for (split //, $modes) {
            $self->{prefix2mode}->{shift @prefixes} = $_;
         }
      }
   }

   if ($self->{isupport}->{NAMESX}
       && !$self->{protoctl}->{NAMESX}) {
      $self->send_srv (PROTOCTL => 'NAMESX');
      $self->{protoctl}->{NAMESX} = 1;
   }

   if ($self->{isupport}->{UHNAMES}
       && !$self->{protoctl}->{UHNAMES}) {
      $self->send_srv (PROTOCTL => 'UHNAMES');
      $self->{protoctl}->{UHNAMES} = 1;
   }

   if (defined (my $chan_prefixes = $self->{isupport}->{CHANTYPES})) {
      $self->{channel_chars} = $chan_prefixes;
   }
}

sub ping_cb {
   my ($self, $msg) = @_;
   $self->send_msg ("PONG", $msg->{params}->[0]);
}

sub pong_cb {
   my ($self, $msg) = @_;
   $self->{last_pong_recv} = time;
}

sub nick_cb {
   my ($self, $msg) = @_;
   my $nick = prefix_nick ($msg);
   my $newnick = $msg->{params}->[0];
   my $wasme = $self->_was_me ($msg);

   if ($wasme) { $self->{nick} = $newnick }

   my @chans;

   for my $channame (keys %{$self->{channel_list}}) {
      my $chan = $self->{channel_list}->{$channame};
      if (exists $chan->{$nick}) {
         $chan->{$newnick} = delete $chan->{$nick};

         push @chans, $channame;
      }
   }

   $self->event (nick_change => $nick, $newnick, $wasme);

   for (@chans) {
      $self->event (channel_change => $_, $nick, $newnick, $wasme);
   }
}

sub namereply_cb {
   my ($self, $msg) = @_;
   my @nicks = split / /, $msg->{params}->[-1];
   push @{$self->{_tmp_namereply}}, @nicks;
}

sub endofnames_cb {
   my ($self, $msg) = @_;
   my $chan = $msg->{params}->[1];
   my @names_result = @{delete $self->{_tmp_namereply}};
   my @modes  = map { ($self->split_nick_mode ($_))[0] } @names_result;
   my @nicks  = map { ($self->split_nick_mode ($_))[1] } @names_result;
   my @idents = grep { defined } map { ($self->split_nick_mode ($_))[2] } @names_result;
   my @new_nicks = $self->_filter_new_nicks_from_channel ($chan, @nicks);

   $self->channel_add ($msg, $chan, \@nicks, \@modes);
   $self->update_ident ($_) for @idents;
   $self->event (channel_add => $msg, $chan, @new_nicks) if @new_nicks;
}

sub whoreply_cb {
   my ($self, $msg) = @_;
   my (undef, $channel, $user, $host, $server, $nick) = @{$msg->{params}};
   $self->update_ident (join_prefix ($nick, $user, $host));
}

sub whoisuser_cb {
   my ($self, $msg) = @_;
   my (undef, $nick, $user, $host) = @{$msg->{params}};
   $self->update_ident (join_prefix ($nick, $user, $host));
}

sub join_cb {
   my ($self, $msg) = @_;
   my $chan = $msg->{params}->[0];
   my $nick = prefix_nick ($msg);

   my @new_nicks = $self->_filter_new_nicks_from_channel ($chan, $nick);

   $self->channel_add ($msg, $chan, [$nick], [undef]);
   $self->event (channel_add => $msg, $chan, @new_nicks) if @new_nicks;
   $self->event (join        => $nick, $chan, $self->_was_me ($msg));

   if ($self->_was_me ($msg) && !$self->isupport ('UHNAMES')) {
      $self->send_srv (WHO => $chan);
   }
}

sub part_cb {
   my ($self, $msg) = @_;
   my $chan = $msg->{params}->[0];
   my $nick = prefix_nick ($msg);

   $self->event (part => $nick, $chan, $self->_was_me ($msg), $msg->{params}->[1]);
   $self->channel_remove ($msg, $chan, [$nick]);
   $self->event (channel_remove => $msg, $chan, $nick);
}

sub kick_cb {
   my ($self, $msg) = @_;
   my $chan        = $msg->{params}->[0];
   my $kicked_nick = $msg->{params}->[1];

   $self->event (kick           => $kicked_nick, $chan, $self->_was_me ($msg), $msg->{params}->[1]);
   $self->channel_remove ($msg, $chan, [$kicked_nick]);
   $self->event (channel_remove => $msg, $chan, $kicked_nick);
}

sub quit_cb {
   my ($self, $msg) = @_;
   my $nick = prefix_nick ($msg);

   $self->event (quit => $nick, $msg->{params}->[1]);

   for (keys %{$self->{channel_list}}) {
      if ($self->{channel_list}->{$_}->{$nick}) {
         $self->channel_remove ($msg, $_, [$nick]);
         $self->event (channel_remove => $msg, $_, $nick);
      }
   }
}

sub mode_cb {
   my ($self, $msg) = @_;
   my $changer = prefix_nick ($msg);
   my ($target, $mode, $dest) = (@{$msg->{params}});

   if ($self->is_channel_name ($target)) {
      if ($mode =~ /^([+-])(\S+)$/ && defined $dest) {
         my ($op, $mode) = ($1, $2);

         if (defined $self->map_mode_to_prefix ($mode)) {
            $self->channel_mode_change ($target, $op, $mode, $dest);
            $self->event (channel_nickmode_update => $target, $dest);
         }
      }
   }
}

sub away_change_cb {
   my ($self, $msg) = @_;

   if ($msg->{command} eq '305') { # no longer away
      delete $self->{away_status};
   } else { # away
      $self->{away_status} = 1;
   }

   $self->event (away_status_change => $self->{away_status});
}

sub debug_cb {
   my ($self, $msg) = @_;
   $self->event (debug_recv => $msg);
}

sub change_nick_login_cb {
   my ($self, $msg) = @_;

   if ($self->registered) {
      delete $self->{change_nick_cb_guard};

   } else {
      my $newnick = $self->{nick_change}->($self->nick);

      if ($self->lower_case ($newnick) eq $self->lower_case ($self->{nick})) {
         $self->disconnect ("couldn't change nick to non-conflicting one");
         return 0;
      }

      $self->{nick} = $newnick;
      $self->send_msg ("NICK", $newnick);
   }
}

sub disconnect_cb {
   my ($self) = @_;

   for (keys %{$self->{channel_list}}) {
      $self->channel_remove (undef, $_, [$self->nick]);
      $self->event (channel_remove => undef, $_, $self->nick)
   }

   $self->cleanup;
}

sub rpl_topic_cb {
   my ($self, $msg) = @_;
   my $chan  = $msg->{params}->[1];
   my $topic = $msg->{params}->[-1];

   $self->event (channel_topic => $chan, $topic);
}

sub topic_change_cb {
   my ($self, $msg) = @_;
   my $who   = prefix_nick ($msg);
   my $chan  = $msg->{params}->[0];
   my $topic = $msg->{params}->[-1];

   $self->event (channel_topic => $chan, $topic, $who);
}

sub update_ident_cb {
   my ($self, $msg) = @_;

   if (is_nick_prefix ($msg->{prefix})) {
      $self->update_ident ($msg->{prefix});
   }
}

sub update_ident_nick_change_cb {
   my ($self, $old, $new) = @_;

   my $oldid = $self->nick_ident ($old);
   return unless defined $oldid;

   my ($n, $u, $h) = split_prefix ($oldid);

   $self->update_ident (join_prefix ($new, $u, $h));
}

sub ctcp_auto_reply_cb {
   my ($self, $src, $targ, $tag, $msg, $type) = @_;

   return if $type ne 'PRIVMSG';

   my $ctcprepl = $self->{ctcp_auto_replies}->{$tag}
      or return;

   if (ref ($ctcprepl->[0]) eq 'CODE') {
      $ctcprepl = [$ctcprepl->[0]->($self, $src, $targ, $tag, $msg, $type)]
   }

   $self->send_msg (NOTICE => $src, encode_ctcp (@$ctcprepl));
}

=back

=head1 EXAMPLES

See samples/anyeventirccl and other samples in samples/ for some examples on how to use AnyEvent::IRC::Client.

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

L<AnyEvent::IRC::Connection>

RFC 1459 - Internet Relay Chat: Client Protocol

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
