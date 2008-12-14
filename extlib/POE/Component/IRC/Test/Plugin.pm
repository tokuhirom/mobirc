package POE::Component::IRC::Test::Plugin;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );

sub new {
    return bless { @_[1..$#_] }, $_[0];
}

sub PCI_register {
    $_[1]->plugin_register( $_[0], 'SERVER', qw(all) );
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub _default {
    return PCI_EAT_NONE;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Test::Plugin - Part of the
L<POE::Component::IRC|POE::Component::IRC> test-suite.

=head1 SYNOPSIS

 use Test::More tests => 16;
 BEGIN { use_ok('POE::Component::IRC') };
 BEGIN { use_ok('POE::Component::IRC::Test::Plugin') };
 use POE;

 my $self = POE::Component::IRC->spawn( );

 isa_ok ( $self, 'POE::Component::IRC' );

 POE::Session->create(
     inline_states => { _start => \&test_start, },
     package_states => [
         main => [ qw(irc_plugin_add irc_plugin_del) ],
     ],
 );

  $poe_kernel->run();

 sub test_start {
     my ($kernel, $heap) = @_[KERNEL, HEAP];

     $self->yield( 'register' => 'all' );

     my $plugin = POE::Component::IRC::Test::Plugin->new();
     isa_ok ( $plugin, 'POE::Component::IRC::Test::Plugin' );
  
     $heap->{counter} = 6;
     if ( !$self->plugin_add( 'TestPlugin' => $plugin ) ) {
         fail( 'plugin_add' );
         $self->yield( 'unregister' => 'all' );
         $self->yield( 'shutdown' );
     }
     
     return:
 }

 sub irc_plugin_add {
     my ($kernel, $heap, $desc, $plugin) = @_[KERNEL, HEAP, ARG0, ARG1];

     isa_ok ( $plugin, 'POE::Component::IRC::Test::Plugin' );
  
     if ( !$self->plugin_del( 'TestPlugin' ) ) {
         fail( 'plugin_del' );
         $self->yield( 'unregister' => 'all' );
         $self->yield( 'shutdown' );
     }
 
     return;
 }

 sub irc_plugin_del {
     my ($kernel, $heap, $desc, $plugin) = @_[KERNEL, HEAP, ARG0, ARG1];

     isa_ok ( $plugin, 'POE::Component::IRC::Test::Plugin' );
     $heap->{counter}--;
     if ( $heap->{counter} <= 0 ) {
         $self->yield( 'unregister' => 'all' );
         $self->yield( 'shutdown' );
     }
     else {
         if ( !$self->plugin_add( 'TestPlugin' => $plugin ) ) {
             fail( 'plugin_add' );
             $self->yield( 'unregister' => 'all' );
             $self->yield( 'shutdown' );
         }
     }
     
     return:
 }

=head1 DESCRIPTION

POE::Component::IRC::Test::Plugin is a very simple
L<POE::Component::IRC|POE::Component::IRC> plugin used to test that the plugin
system is working correctly, as demonstrated in the L<SYNOPSIS>.

=head1 CONSTRUCTOR

=over

=item C<new>

No arguments required, returns an POE::Component::IRC::Test::Plugin object.

=back

=head1 AUTHOR

Chris "BinGOs" Williams

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

=cut

