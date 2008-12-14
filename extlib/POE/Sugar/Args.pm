package POE::Sugar::Args;
# $Id: Args.pm,v 1.1 2003/09/30 22:06:19 cwest Exp $
use strict;

use POE::Session;
use Devel::Caller::Perl qw[called_args];
use Exporter::Lite;
use vars qw[$VERSION @EXPORT];

$VERSION = '1.3';
@EXPORT  = qw[sweet_args];

=head1 NAME

POE::Sugar::Args - Get "pretty", OO representation of args.

=head1 SYNOPSIS

 use POE::Sugar::Args;

 sub _start {
   my $poe = sweet_args;
   $poe->kernel->yield( '_stop' );
 }

 # or, the long, boring way
 
 sub _stop {
   my $poe = POE::Sugar::Args->new( @_ );
   delete $poe->heap->{client};
 }

=head1 ABSTRACT

This module give an OO representation to arguments POE passes to event
states.  I will not lie to you.  This adds heavy, bulky code underneath.
On the other hand, it makes arguments for POE events much more
palatable.  Of course, this is a Sugar module, meaning, it will rot
your program in odd (you'll be hooked) and unexpected ways (performace),
but you took the candy so you can suffer the consequences.  Good luck.

=head1 DESCRIPTION

=head2 Exports

=head3 sweet_args

This function will get C<@_> from the calling state by doing deep,
dark voodoo.  It will construct the C<POE::Sugar::Args> object for
you.  Very handy.

=head2 Methods

=head3 new

Constructs an object.  Expects all of C<@_> that's passed to an event
state.

=head3 object

If this state was initialized as an C<object_state> in the session,
the object will be here.

=head3 session

L<POE::Session|POE::Kernel> object.

=head3 kernel

L<POE::Kernel|POE::Kernel> object.

=head3 heap

Your heap.

=head3 state

Event name that invoked the state.

=head3 sender

Reference to the session that send the event.

=head3 caller_file

The calling file.

=head3 caller_line

The calling line.

=head3 args

All arguments this event was called with.

=cut

sub sweet_args   { __PACKAGE__->new( called_args ) }
sub new          { bless [ @_[1..$#_] ], $_[0]     }
sub object       { $_[0]->[OBJECT]                 }
sub session      { $_[0]->[SESSION]                }
sub kernel       { $_[0]->[KERNEL]                 }
sub heap         { $_[0]->[HEAP]                   }
sub state        { $_[0]->[STATE]                  }
sub sender       { $_[0]->[SENDER]                 }
sub caller_file  { $_[0]->[CALLER_FILE]            }
sub caller_line  { $_[0]->[CALLER_LINE]            }
sub args         { wantarray ?
                   @{$_[0]}[ARG0 .. $#{$_[0]}] :
                   [ @{$_[0]}[ARG0 .. $#{$_[0]}] ] }

1;

__END__

=pod

=head1 AUTHOR

Casey West <F<casey@geeknest.com>>

=head1 THANKS

Rocco Caputo -- Much help with code and overall inspiration.

=head1 COPYRIGHT

Copyright (c) 2003 Casey West.  All rights reserved.  This
program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>, L<Devel::Caller>, L<DB>, L<perldebguts>.

=cut
