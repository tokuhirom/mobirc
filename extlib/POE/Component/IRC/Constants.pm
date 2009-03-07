package POE::Component::IRC::Constants;

use strict;
use warnings;

our $VERSION = '6.02';

require Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(
    PCI_REFCOUNT_TAG PRI_LOGIN PRI_HIGH PRI_NORMAL MSG_PRI MSG_TEXT
    CMD_PRI CMD_SUB
);
our %EXPORT_TAGS = ( ALL => [@EXPORT_OK] );

use constant {
    # The name of the reference count P::C::I keeps in client sessions.
    PCI_REFCOUNT_TAG => 'P::C::I registered',

    # Message priorities.
    PRI_LOGIN  => 10, # PASS/NICK/USER messages must go first.
    PRI_HIGH   => 20, # KICK/MODE etc. is more important than chatter.
    PRI_NORMAL => 30, # Random chatter.

    MSG_PRI  => 0, # Queued message priority.
    MSG_TEXT => 1, # Queued message text.

    # RCC: Since most of the commands are data driven, I have moved their
    # event/handler maps here and added priorities for each data driven
    # command.  The priorities determine message importance when messages
    # are queued up.  Lower ones get sent first.
    CMD_PRI => 0, # Command priority.
    CMD_SUB => 1, # Command handler.
};

1;
__END__

=head1 NAME

POE::Component::IRC::Constants - Defines constants required by
L<POE::Component::IRC|POE::Component::IRC>

=head1 SYNOPSIS

 use POE::Component::IRC::Constants qw(:ALL);

=head1 DESCRIPTION

POE::Component::IRC::Constants defines constants required by
L<POE::Component::IRC|POE::Component::IRC> and derived sub-classes.

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

=cut
