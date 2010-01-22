package AnyEvent::IRC;
use common::sense;
use AnyEvent;

=head1 NAME

AnyEvent::IRC - An event system independend IRC protocol module

=head1 VERSION

Version 0.95

=cut

our $VERSION = '0.95';

=head1 SYNOPSIS

Using the simplistic L<AnyEvent::IRC::Connection>:

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

Using the more sophisticated L<AnyEvent::IRC::Client>:

   use AnyEvent;
   use AnyEvent::IRC::Client;

   my $c = AnyEvent->condvar;

   my $timer;
   my $con = new AnyEvent::IRC::Client;

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

The L<AnyEvent::IRC> module consists of L<AnyEvent::IRC::Connection>,
L<AnyEvent::IRC::Client> and L<AnyEvent::IRC::Util>. L<AnyEvent::IRC>
is just a module that holds this overview over the other modules.

L<AnyEvent::IRC> can be viewed as toolbox for handling IRC connections
and communications. It won't do everything for you, and you still
need to know a few details of the IRC protocol.

L<AnyEvent::IRC::Client> is a more highlevel IRC connection
that already processes some messages for you and will generated some
events that are maybe useful to you. It will also do PING replies for you,
manage channels a bit, nicknames and CTCP.

L<AnyEvent::IRC::Connection> is a lowlevel connection that only connects
to the server and will let you send and receive IRC messages.
L<AnyEvent::IRC::Connection> does not imply any client behaviour, you could also
use it to implement an IRC server.

Note that these modules use L<AnyEvent> as it's IO event subsystem.
You can integrate them into any application with a event system
that L<AnyEvent> has support for (eg. L<Gtk2> or L<Event>).

=head1 EXAMPLES

See the samples/ directory for some examples on how to use AnyEvent::IRC.

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

L<AnyEvent::IRC::Util>

L<AnyEvent::IRC::Connection>

L<AnyEvent::IRC::Client>

L<AnyEvent>

RFC 1459 - Internet Relay Chat: Client Protocol

RFC 2812 - Internet Relay Chat: Client Protocol

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-irc3 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-IRC>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::IRC

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-IRC>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-IRC>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-IRC>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-IRC>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Marc Lehmann for the new AnyEvent module!

And these people have helped to work on L<AnyEvent::IRC>:

   * Maximilian Gass - Added support for ISUPPORT and CASEMAPPING.
   * Zaba            - Thanks for the useful input about IRC.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
