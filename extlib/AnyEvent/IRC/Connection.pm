package AnyEvent::IRC::Connection;
use common::sense;
use AnyEvent;
use POSIX;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::IRC::Util qw/mk_msg parse_irc_msg/;
use Object::Event;

use base Object::Event::;

=head1 NAME

AnyEvent::IRC::Connection - An IRC connection abstraction

=head1 SYNOPSIS

   use AnyEvent;
   use AnyEvent::IRC::Connection;

   my $c = AnyEvent->condvar;

   my $con = new AnyEvent::IRC::Connection;

   $con->connect ("localhost", 6667);

   $con->reg_cb (
      connect => sub {
         my ($con) = @_;
         $con->send_msg (NICK => 'testbot');
         $con->send_msg (USER => 'testbot', '*', '0', 'testbot');
      },
      irc_001 => sub {
         my ($con) = @_;
         print "$_[1]->{prefix} says I'm in the IRC: $_[1]->{params}->[-1]!\n";
         $c->broadcast;
      }
   );

   $c->wait;

=head1 DESCRIPTION

The connection class. Here the actual interesting stuff can be done,
such as sending and receiving IRC messages. And it also handles
TCP connecting and even enabling of TLS.

Please note that CTCP support is available through the functions
C<encode_ctcp> and C<decode_ctcp> provided by L<AnyEvent::IRC::Util>.

=head2 METHODS

=over 4

=item $con = AnyEvent::IRC::Connection->new ()

This constructor doesn't take any arguments.

B<NOTE:> You are free to use the hash member C<heap> (which contains a hash) to
store any associated data with this object. For example retry timers or
anything else.

You can also access that member via the C<heap> method.

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;

  my $self = $class->SUPER::new (@_, heap => { });

  bless $self, $class;

  $self->reg_cb (
     ext_after_send => sub {
        my ($self, $mkmsg_args) = @_;
        $self->send_raw (mk_msg (@$mkmsg_args));
     }
  );

  return $self;
}

=item $con->connect ($host, $port [, $prepcb_or_timeout])

Tries to open a socket to the host C<$host> and the port C<$port>.
If an error occurred it will die (use eval to catch the exception).

If you want to connect via TLS/SSL you have to call the C<enable_ssl>
method before to enable it.

C<$prepcb_or_timeout> can either be a callback with the semantics of a prepare
callback for the function C<tcp_connect> in L<AnyEvent::Socket> or a simple
number which stands for a timeout.

=cut

sub connect {
   my ($self, $host, $port, $prep) = @_;

   if ($self->{socket}) {
      $self->disconnect ("reconnect requested.");
   }

   $self->{con_guard} =
      tcp_connect $host, $port, sub {
         my ($fh) = @_;

         delete $self->{socket};

         unless ($fh) {
            $self->event (connect => $!);
            return;
         }

         $self->{host} = $host;
         $self->{port} = $port;

         $self->{socket} =
            AnyEvent::Handle->new (
               fh => $fh,
               ($self->{enable_ssl} ? (tls => 'connect') : ()),
               on_eof => sub {
                  $self->disconnect ("EOF from server $host:$port");
               },
               on_error => sub {
                  $self->disconnect ("error in connection to server $host:$port: $!");
               },
               on_read => sub {
                  my ($hdl) = @_;
                  $hdl->push_read (line => sub {
                     $self->_feed_irc_data ($_[1]);
                  });
               },
               on_drain => sub {
                  $self->event ('buffer_empty');
               }
            );

         $self->event ('connect');
      }, (defined $prep ? (ref $prep ? $prep : sub { $prep }) : ());
}

=item $con->enable_ssl ()

This method will enable SSL for new connections that are initiated by C<connect>.

=cut

sub enable_ssl {
   my ($self) = @_;
   $self->{enable_ssl} = 1;
}

=item $con->disconnect ($reason)

Unregisters the connection in the main AnyEvent::IRC object, closes
the sockets and send a 'disconnect' event with C<$reason> as argument.

=cut

sub disconnect {
   my ($self, $reason) = @_;

   delete $self->{con_guard};
   delete $self->{socket};
   $self->event (disconnect => $reason);
}

=item $con->is_connected

Returns true when this connection is connected.
Otherwise false.

=cut

sub is_connected {
   my ($self) = @_;
   $self->{socket} && $self->{connected}
}

=item $con->heap ()

Returns the hash reference stored in the C<heap> member, that is local to this
connection object that lets you store any information you want.

=cut

sub heap {
   my ($self) = @_;
   return $self->{heap};
}

=item $con->send_raw ($ircline)

This method sends C<$ircline> straight to the server without any
further processing done.

=cut

sub send_raw {
   my ($self, $ircline) = @_;

   return unless $self->{socket};
   $self->{socket}->push_write ($ircline . "\015\012");
}

=item $con->send_msg ($command, @params)

This function sends a message to the server. C<@ircmsg> is the argument list
for C<AnyEvent::IRC::Util::mk_msg (undef, $command, @params)>.

=cut

sub send_msg {
   my ($self, @msg) = @_;

   $self->event (send => [undef, @msg]);
   $self->event (sent => undef, @msg);
}

sub _feed_irc_data {
   my ($self, $line) = @_;

   #d# warn "LINE:[" . $line . "][".length ($line)."]";

   my $m = parse_irc_msg ($line);
   #d# warn "MESSAGE{$m->{params}->[-1]}[".(length $m->{params}->[-1])."]\n";
   #d# warn "HEX:" . join ('', map { sprintf "%2.2x", ord ($_) } split //, $line)
   #d#     . "\n";

   $self->event (read => $m);
   $self->event ('irc_*' => $m);
   $self->event ('irc_' . (lc $m->{command}), $m);
}

=back

=head2 EVENTS

Following events are emitted by this module and shouldn't be emitted
from a module user call to C<event>. See also the documents L<Object::Event> about
registering event callbacks.

=over 4

=item connect => $error

This event is generated when the socket was successfully connected
or an error occurred while connecting. The error is given as second
argument (C<$error>) to the callback then.

=item disconnect => $reason

This event will be generated if the connection is somehow terminated.
It will also be emitted when C<disconnect> is called.
The second argument to the callback is C<$reason>, a string that contains
a clue about why the connection terminated.

If you want to reestablish a connection, call C<connect> again.

=item send => $ircmsg

Emitted when a message is about to be sent. C<$ircmsg> is an array reference
to the arguments of C<mk_msg> (see L<AnyEvent::IRC::Util>). You
may modify the array reference to change the message or even intercept it
completely by calling C<stop_event> (see L<Object::Event> API):

   $con->reg_cb (
      send => sub {
         my ($con, $ircmsg) = @_;

         if ($ircmsg->[1] eq 'NOTICE') {
            $con->stop_event; # prevent any notices from being sent.

         } elsif ($ircmsg->[1] eq 'PRIVMSG') {
            $ircmsg->[-1] =~ s/sex/XXX/i; # censor any outgoing private messages.
         }
      }
   );

=item sent => @ircmsg

Emitted when a message (C<@ircmsg>) was sent to the server.
C<@ircmsg> are the arguments to C<AnyEvent::IRC::Util::mk_msg>.

=item irc_* => $msg

=item irc_<lowercase command> => $msg

=item read => $msg

Emitted when a message (C<$msg>) was read from the server.
C<$msg> is the hash reference returned by C<AnyEvent::IRC::Util::parse_irc_msg>;

Note: '<lowercase command>' stands for the command of the message in
(ASCII) lower case.

=item buffer_empty

This event is emitted when the write buffer of the underlying connection
is empty and all data has been given to the kernel. See also C<samples/notify>
about a usage example.

Please note that this buffer is NOT the queue mentioned in L<AnyEvent::IRC::Client>!

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

L<AnyEvent::IRC>

L<AnyEvent::IRC::Client>

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
