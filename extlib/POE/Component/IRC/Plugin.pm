package POE::Component::IRC::Plugin;

use strict;
use warnings;

our $VERSION = '6.02';

require Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(PCI_EAT_NONE PCI_EAT_CLIENT PCI_EAT_PLUGIN PCI_EAT_ALL);
our %EXPORT_TAGS = ( ALL => [@EXPORT_OK] );

use constant {
    PCI_EAT_NONE   => 1,
    PCI_EAT_CLIENT => 2,
    PCI_EAT_PLUGIN => 3,
    PCI_EAT_ALL    => 4,
};

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin - Provides plugin constants and documentation for 
L<POE::Component::IRC|POE::Component::IRC>

=head1 SYNOPSIS

 # A simple ROT13 'encryption' plugin

 package Rot13;

 use strict;
 use warnings;
 use POE::Component::IRC::Plugin qw( :ALL );

 # Plugin object constructor
 sub new {
     my $package = shift;
     return bless {}, $package;
 }

 sub PCI_register {
     my ($self, $irc) = splice @_, 0, 2;

     $irc->plugin_register( $self, 'SERVER', qw(public) );
     return 1;
 }

 # This is method is mandatory but we don't actually have anything to do.
 sub PCI_unregister {
     return 1;
 }

 sub S_public {
     my ($self, $irc) = splice @_, 0, 2;

     # Parameters are passed as scalar-refs including arrayrefs.
     my $nick    = ( split /!/, ${ $_[0] } )[0];
     my $channel = ${ $_[1] }->[0];
     my $msg     = ${ $_[2] };

     if (my ($rot13) = $msg =~ /^rot13 (.+)/) {
         $rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];

         # Send a response back to the server.
         $irc->yield( privmsg => $channel => $rot13 );
         # We don't want other plugins to process this
         return PCI_EAT_PLUGIN;
     }

     # Default action is to allow other plugins to process it.
     return PCI_EAT_NONE;
 }

=head1 DESCRIPTION

POE::Component::IRC's plugin system has been released separately as
L<POE::Component::Pluggable|POE::Component::Pluggable>. Gleaning at its
documentation is advised. The rest of this document mostly describes aspects
that are specific to POE::Component::IRC's use of POE::Component::Pluggable.

=head1 HISTORY

Certain individuals in #PoE on MAGNet said we didn't need to bloat the
PoCo-IRC code...

BinGOs, the current maintainer of the module, and I heartily agreed that this
is a wise choice.

One example:

Look at the magnificent new feature in 3.4 -> irc_whois replies! Yes, that is
a feature I bet most of us have been coveting for a while, as it definitely
makes our life easier. It was implemented in 30 minutes or so after a request,
the maintainer said. I replied by saying that it's a wonderful idea, but what
would happen if somebody else asked for a new feature? Maybe thatfeature is
something we all would love to have, so should it be put in the core? Plugins
allow the core to stay lean and mean, while delegating additional functionality
to outside modules. BinGOs' work with making PoCo-IRC inheritable is wonderful,
but what if there were 2 modules which have features that you would love to
have in your bot? Inherit from both? Imagine the mess...

Here comes plugins to the rescue :)

You could say Bot::Pluggable does the job, and so on, but if this feature were
put into the core, it would allow PoCo-IRC to be extended beyond our wildest
dreams, and allow the code to be shared amongst us all, giving us superior bug
smashing abilities.

Yes, there are changes that most of us will moan when we go update our bots to
use the new C<$irc> object system, but what if we also used this opportunity to
improve PoCo-IRC even more and give it a lifespan until Perl8 or whatever comes
along? :)

=head1 DESCRIPTION

The plugin system works by letting coders hook into the two aspects of PoCo-IRC:

=over

=item *

Data received from the server

=item *

User commands about to be sent to the server

=back

The goal of this system is to make PoCo-IRC so easy to extend, enabling it to
Take Over The World! *Just Kidding*

The general architecture of using the plugins should be:

 # Import the stuff...
 use POE;
 use POE::Component::IRC;
 use POE::Component::IRC::Plugin::ExamplePlugin;

 # Create our session here
 POE::Session->create( ... );

 # Create the IRC session here
 my $irc = POE::Component::IRC->spawn() or die "Oh noooo! $!";

 # Create the plugin
 # Of course it could be something like $plugin = MyPlugin->new();
 my $plugin = POE::Component::IRC::Plugin::ExamplePlugin->new( ... );

 # Hook it up!
 $irc->plugin_add( 'ExamplePlugin', $plugin );

 # OOPS, we lost the plugin object!
 my $pluginobj = $irc->plugin_get( 'ExamplePlugin' );

 # We want a list of plugins and objects
 my $hashref = $irc->plugin_list();

 # Oh! We want a list of plugin aliases.
 my @aliases = keys %{ $irc->plugin_list() };

 # Ah, we want to remove the plugin
 $plugin = $irc->plugin_del( 'ExamplePlugin' );

The plugins themselves will conform to the standard API described here. What
they can do is limited only by imagination and the IRC RFC's ;)

 # Import the constants
 use POE::Component::IRC::Plugin qw( :ALL );

 # Our constructor
 sub new {
     ...
 }

 # Required entry point for PoCo-IRC
 sub PCI_register {
     my ($self, $irc) = @_;
     # Register events we are interested in
     $irc->plugin_register( $self, 'SERVER', qw( 355 kick whatever) );

     # Return success
     return 1;
 }

 # Required exit point for PoCo-IRC
 sub PCI_unregister {
     my ($self, $irc) = @_;

     # PCI will automatically unregister events for the plugin

     # Do some cleanup...

     # Return success
     return 1;
 }

 # Registered events will be sent to methods starting with IRC_
 # If the plugin registered for SERVER - irc_355
 sub S_355 {
     my($self, $irc, $line) = @_;

     # Remember, we receive pointers to scalars, so we can modify them
     $$line = 'frobnicate!';

     # Return an exit code
     return PCI_EAT_NONE;
 }

 # Default handler for events that do not have a corresponding plugin
 # method defined.
 sub _default {
     my ($self, $irc, $event) = splice @_, 0, 3;

     print "Default called for $event\n";

     # Return an exit code
     return PCI_EAT_NONE;
 }

Plugins can even embed their own POE sessions if they need to do fancy stuff.
Below is a template for a plugin which does just that.

 package POE::Plugin::Template;

 use POE;
 use POE::Component::IRC::Plugin qw( :ALL );

 sub new {
     my $package = shift;
     my $self = bless {@_}, $package;
     return $self;
 }

 sub PCI_register {
     my ($self, $irc) = splice @_, 0, 2;

     # We store a ref to the $irc object so we can use it in our
     # session handlers.
     $self->{irc} = $irc;

     $irc->plugin_register( $self, 'SERVER', qw(blah blah blah) );

     $self->{SESSION_ID} = POE::Session->create(
         object_states => [
             $self => [qw(_start _shutdown)],
         ],
     )->ID();

     return 1;
 }

 sub PCI_unregister {
     my ($self, $irc) = splice @_, 0, 2;
     # Plugin is dying make sure our POE session does as well.
     $poe_kernel->call( $self->{SESSION_ID} => '_shutdown' );
     delete $self->{irc};
     return 1;
 }

 sub _start {
     my ($kernel, $self) = @_[KERNEL, OBJECT];
     $self->{SESSION_ID} = $_[SESSION]->ID();
     # Make sure our POE session stays around. Could use aliases but that is so messy :)
     $kernel->refcount_increment( $self->{SESSION_ID}, __PACKAGE__ );
     return;
 }

 sub _shutdown {
     my ($kernel, $self) = @_[KERNEL, OBJECT];
     $kernel->alarm_remove_all();
     $kernel->refcount_decrement( $self->{SESSION_ID}, __PACKAGE__ );
     return;
 }

=head1 EVENT TYPES

=head2 SERVER hooks

Hooks that are targeted toward data received from the server will get the exact
same arguments as if it was a normal event, look at the PoCo-IRC docs for more
information.

NOTE: Server methods are identified in the plugin namespace by the subroutine
prefix of S_*. I.e. an irc_kick event handler would be:

 sub S_kick {}

The only difference is instead of getting scalars, the hook will get a
reference to the scalar, to allow it to mangle the data. This allows the plugin
to modify data *before* they are sent out to registered sessions.

They are required to return one of the L<exit codes|/"EXIT CODES"> so PoCo-IRC
will know what to do.

=head3 Names of potential hooks

 001
 socketerr
 connected
 plugin_del
 ...

Keep in mind that they are always lowercased. Check out the
L<OUTPUT|POE::Component::IRC/"OUTPUT"> section of POE::Component::IRC's
documentation for the complete list of events.

=head2 USER hooks

These type of hooks have two different argument formats. They are split between
data sent to the server, and data sent through DCC connections.

NOTE: User methods are identified in the plugin namespace by the subroutine
prefix of U_*. I.e. an irc_kick event handler would be:

 sub U_kick {}

Hooks that are targeted to user data have it a little harder. They will receive
a reference to the raw line about to be sent out. That means they will have to
parse it in order to extract data out of it.

The reasoning behind this is that it is not possible to insert hooks in every
method in the C<$irc> object, as it will become unwieldy and not allow inheritance
to work.

The DCC hooks have it easier, as they do not interact with the server, and will
receive references to the arguments specified in the DCC plugin
L<documentation|POE::Component::IRC::Plugin::DCC/"COMMANDS"> regarding dcc commands.

=head3 Names of potential hooks

 kick
 dcc_chat
 ison
 privmsg
 ...

Keep in mind that they are always lowercased, and are extracted from the raw
line about to be sent to the irc server. To be able to parse the raw line, some
RFC reading is in order. These are the DCC events that are not given a raw
line, they are:

 dcc        - $nick, $type, $file, $blocksize, $timeout
 dcc_accept - $cookie, $myfile
 dcc_resume - $cookie
 dcc_chat   - $cookie, @lines
 dcc_close  - $cookie

=head2 _default

If a plugin has registered for an event but doesn't have a hook method
defined for ir, component will attempt to call a plugin's C<_default> method.
The first parameter after the plugin and irc objects will be the handler name.

 sub _default {
     my ($self, $irc, $event) = splice @_, 0, 3;

     # $event will be something like S_public or U_dcc, etc.
     return PCI_EAT_NONE;
 }

The C<_default> handler is expected to return one of the exit codes so PoCo-IRC
will know what to do.

=head1 EXIT CODES

=head2 PCI_EAT_NONE

This means the event will continue to be processed by remaining plugins and
finally, sent to interested sessions that registered for it.

=head2 PCI_EAT_CLIENT

This means the event will continue to be processed by remaining plugins but
it will not be sent to any sessions that registered for it. This means nothing
will be sent out on the wire if it was an USER event, beware!

=head2 PCI_EAT_PLUGIN

This means the event will not be processed by remaining plugins, it will go
straight to interested sessions.

=head2 PCI_EAT_ALL

This means the event will be completely discarded, no plugin or session will
see it. This means nothing will be sent out on the wire if it was an USER
event, beware!

=head1 EXPORTS

Exports the return constants for plugins to use in @EXPORT_OK
Also, the ':ALL' tag can be used to get all of them.

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

L<POE::Component::Pluggable|POE::Component::Pluggable>

L<POE::Component::Pluggable::Pipeline|POE::Component::Pluggable::Pipeline>

L<POE::Session|POE::Session>

=head1 AUTHOR

Apocalypse <apocal@cpan.org>

=cut
