=head1 NAME

POE::Component::IRC::Projects - Listing of projects that use L<POE::Component::IRC>.

=head1 SYNOPSIS

 perldoc POE::Component::IRC::Projects

=head1 DESCRIPTION

POE::Component::IRC::Projects strives to document projects that are using
L<POE::Component::IRC|POE::Component::IRC>>. Projects can include subclasses,
bot frameworks, bots, etc. The only stipulation for inclusion is that the
project utilises L<POE::Component::IRC|POE::Component::IRC>>.

Inclusion to ( or inversely, exclusion from ) this list does not imply any sort
of endorsement ( or disapproval ) of the said project.

=head1 BOT FRAMEWORKS ( CPAN )

An alphabetically ordered list of bot frameworks, that are available on CPAN.

=over

=item L<Amethyst|Amethyst>

Amethyst is a bot core capable of handling parsing and routing of messages
between connections and brains. Amethyst can handle an arbitrary number of
connections of arbitrary types (given an appropriate module in
Amethyst::Connection::*), routing these messages fairly arbitrarily through
multiple processing cores (brains, live in Amethyst::Brain::*), and responding
to these messages on other arbitrary connections.

=item L<Bot::BasicBot|Bot::BasicBot>

Basic bot system designed to make it easy to do simple bots, optionally forking
longer processes (like searches) concurrently in the background.

=item L<Bot::Pluggable|Bot::Pluggable>

This is a very small (but important) part of a pluggable IRC bot framework. It
provides the developer with a simply framework for writing Bot components as
Perl modules.

=item L<Bot::Infobot|Bot::Infobot>

Bot::BasicBot::Pluggable based replacement for the venerable infobot.

=item L<IRC::Bot|IRC::Bot>

A complete bot, similar to eggdrop using POE::Component::IRC. Allows access to
all channel user management modes. Provides !seen functions, a complete help
system, logging, dcc chat interface, and it runs as a daemon process. IRC::Bot
utilizes Cache::FileCache for seen functions, and for session handling.

=item L<ThreatNet::Bot::AmmoBot|ThreatNet::Bot::AmmoBot>

ThreatNet::Bot::AmmoBot is the basic foot soldier of the ThreatNet bot
ecosystem, fetching ammunition and bringing it to the channel. It connects to
a single ThreatNet channel, and then tails one or more files scanning for
threat messages while following the basic channel rules.

=back

=head1 EXTENSIONS ( CPAN )

=over

=item L<POE::Component::IRC::Plugin::RSS::Headlines|POE::Component::IRC::Plugin::RSS::Headlines>

A POE::Component::IRC plugin that provides RSS headline retrieval. 

=item L<POE::Component::IRC::Plugin::URI::Find|POE::Component::IRC::Plugin::URI::Find>

A POE::Component::IRC plugin that finds URIs in channel traffic.

=item L<POE::Component::IRC::Plugin::POE::Knee|POE::Component::IRC::Plugin::POE::Knee>

A POE::Component::IRC plugin that runs Acme::POE::Knee races. 

=item L<POE::Component::IRC::Plugin::Blowfish|POE::Component::IRC::Plugin::Blowfish>

A POE::Component::IRC plugin that provides blowfish encryption.

=item L<POE::Component::IRC::Plugin::YouTube::MovieFindStore|POE::Component::IRC::Plugin::YouTube::MovieFindStore>

A plugin for finding, resolving .FLV, and optionally storing YouTube URIs. 

=item L<POE::Component::IRC::Object|POE::Component::IRC::Object>

A slightly simpler OO interface to PoCoIRC

=item L<POE::Component::IRC::Onjoin|POE::Component::IRC::Onjoin>

This module implements a class that provides moved message and onjoin services
as an IRC bot. Based on the configuration parameters passed to it via its
constructor it will connect to a channel on a server and immediately send
everyone on that channel a message privately. It will also send the same
message to the channel itself publically at the specified interval. All users
joining the channel thereafter will also recieve the message.

=back

=head1 PROXIES / BOUNCERS ( CPAN )

=over

=item L<App::Bondage|App::Bondage>

A featureful easy-to-use IRC bouncer.

=back

