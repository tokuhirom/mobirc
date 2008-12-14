=head1 NAME

POE::Component::IRC::Cookbook::Disconnecting - How to disconnect gracefully
with PoCo-IRC

=head1 DESCRIPTION

Shutting down an IRC bot can be quick and messy, or slow and graceful. 

=head1 SYNOPSIS

There are two ways you can shut down an IRC bot/client. The quick and dirty way
is rather simple:

 exit;

It exits the program, shutting down the socket, and everybody online sees yet
another "Connection reset by peer" or "Remote end closed the socket" or
something.

There's a little dance you can do to send a quit message and log out
gracefully. It goes like this: 

=over

=item *

Send the C<QUIT> command to the IRC server, with your quit message. 

=item *

Wait for C<irc_disconnected> to come back.

=item *

Unregister all events. This is like the C<< register => 'all' >> you probably
posted near the C<connect> command, but replace C<register> with C<unregister>.
Once POE::Component::IRC knows your session isn't interested, it lets you go
and things shut down. 

=back

=head1 AUTHOR

Rocco Caputo (I think). PODified by Hinrik E<Ouml>rn SigurE<eth>sson.

