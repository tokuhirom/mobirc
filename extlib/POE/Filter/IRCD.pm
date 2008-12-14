package POE::Filter::IRCD;

use strict;
use warnings;
use Carp;
use vars qw($VERSION);
use base qw(POE::Filter);

$VERSION = '2.38';

sub _PUT_LITERAL () { 1 }

# Probably some other stuff should go here.

my $g = {
  space			=> qr/\x20+/o,
  trailing_space	=> qr/\x20*/o,
};

my $irc_regex = qr/^
  (?:
    \x3a                #  : comes before hand
    (\S+)               #  [prefix]
    $g->{'space'}       #  Followed by a space
  )?                    # but is optional.
  (
    \d{3}|[a-zA-Z]+     #  [command]
  )                     # required.
  (?:
    $g->{'space'}       # Strip leading space off [middle]s
    (                   # [middle]s
      (?:
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      )                 # Match on 1 of these,
      (?:
        $g->{'space'}
        [^\x00\x0a\x0d\x20\x3a]
        [^\x00\x0a\x0d\x20]*
      ){0,13}           # then match on 0-13 of these,
    )
  )?                    # otherwise dont match at all.
  (?:
    $g->{'space'}\x3a   # Strip off leading spacecolon for [trailing]
    ([^\x00\x0a\x0d]*)	# [trailing]
  )?                    # [trailing] is not necessary.
  $g->{'trailing_space'}
$/x;

sub new {
  my $type = shift;
  croak "$type requires an even number of parameters" if @_ % 2;
  my $buffer = { @_ };
  $buffer->{uc $_} = delete $buffer->{$_} for keys %{ $buffer };
  $buffer->{BUFFER} = [];
  return bless $buffer, $type;
}

sub debug {
  my $self = shift;
  my $value = shift;

  if ( defined $value ) {
	$self->{DEBUG} = $value;
	return $self->{DEBUG};
  }
  $self->{DEBUG} = $value;
}

sub get {
  my ($self, $raw_lines) = @_;
  my $events = [];

  foreach my $raw_line (@$raw_lines) {
    warn "->$raw_line \n" if $self->{DEBUG};
    if ( my($prefix, $command, $middles, $trailing) = $raw_line =~ m/$irc_regex/ ) {
      my $event = { raw_line => $raw_line };
      $event->{'prefix'} = $prefix if $prefix;
      $event->{'command'} = uc $command;
      $event->{'params'} = [] if defined ( $middles ) || defined ( $trailing );
      push @{$event->{'params'}}, (split /$g->{'space'}/, $middles) if defined $middles;
      push @{$event->{'params'}}, $trailing if defined $trailing;
      push @$events, $event;
    } 
    else {
      warn "Received line $raw_line that is not IRC protocol\n";
    }
  }
  return $events;
}

sub get_one_start {
  my ($self, $raw_lines) = @_;
  push @{ $self->{BUFFER} }, $_ for @$raw_lines;
}

sub get_one {
  my $self = shift;
  my $events = [];

  if ( my $raw_line = shift ( @{ $self->{BUFFER} } ) ) {
    warn "->$raw_line \n" if $self->{DEBUG};
    if ( my($prefix, $command, $middles, $trailing) = $raw_line =~ m/$irc_regex/ ) {
      my $event = { raw_line => $raw_line };
      $event->{'prefix'} = $prefix if $prefix;
      $event->{'command'} = uc $command;
      $event->{'params'} = [] if defined ( $middles ) || defined ( $trailing );
      push @{$event->{'params'}}, (split /$g->{'space'}/, $middles) if defined $middles;
      push @{$event->{'params'}}, $trailing if defined $trailing;
      push @$events, $event;
    } 
    else {
      warn "Received line $raw_line that is not IRC protocol\n";
    }
  }
  return $events;
}

sub get_pending {
  return;
}

sub put {
  my ($self, $events) = @_;
  my $raw_lines = [];

  foreach my $event (@$events) {
    if (ref $event eq 'HASH') {
      my $colonify = ( defined $event->{colonify} ? $event->{colonify} : $self->{COLONIFY} );
      if ( _PUT_LITERAL || _checkargs($event) ) {
        my $raw_line = '';
        $raw_line .= (':' . $event->{'prefix'} . ' ') if exists $event->{'prefix'};
        $raw_line .= $event->{'command'};
	if ( $event->{'params'} and ref $event->{'params'} eq 'ARRAY' ) {
		my $params = [ @{ $event->{'params'} } ];
		$raw_line .= ' ';
		my $param = shift @$params;
		while (@$params) {
			$raw_line .= $param . ' ';
			$param = shift @$params;
		}
		$raw_line .= ':' if $param =~ m/\x20/ or $colonify;
		$raw_line .= $param;
	}
        push @$raw_lines, $raw_line;
        warn "<-$raw_line \n" if $self->{DEBUG};
      } 
      else {
        next;
      }
    } 
    else {
      warn __PACKAGE__ . " non hashref passed to put(): \"$event\"\n";
      push @$raw_lines, $event if ref $event eq 'SCALAR';
    }
  }
  return $raw_lines;
}

sub clone {
  my $self = shift;
  my $nself = { };
  $nself->{$_} = $self->{$_} for keys %{ $self };
  $nself->{BUFFER} = [ ];
  return bless $nself, ref $self;
}

# This thing is far from correct, dont use it.
sub _checkargs {
  my $event = shift || return;
  warn("Invalid characters in prefix: " . $event->{'prefix'} . "\n")
    if ($event->{'prefix'} =~ m/[\x00\x0a\x0d\x20]/);
  warn("Undefined command passed.\n")
    unless ($event->{'command'} =~ m/\S/o);
  warn("Invalid command: " . $event->{'command'} . "\n")
    unless ($event->{'command'} =~ m/^(?:[a-zA-Z]+|\d{3})$/o);
  foreach my $middle (@{$event->{'middles'}}) {
    warn("Invalid middle: $middle\n")
      unless ($middle =~ m/^[^\x00\x0a\x0d\x20\x3a][^\x00\x0a\x0d\x20]*$/);
  }
  warn("Invalid trailing: " . $event->{'trailing'} . "\n")
    unless ($event->{'trailing'} =~ m/^[\x00\x0a\x0d]*$/);
}

1;

__END__

=head1 NAME

POE::Filter::IRCD - A POE-based parser for the IRC protocol.

=head1 SYNOPSIS

    use POE::Filter::IRCD;

    my $filter = POE::Filter::IRCD->new( debug => 1, colonify => 0 );
    my $arrayref = $filter->get( [ $hashref ] );
    my $arrayref2 = $filter->put( $arrayref );

    use POE qw(Filter::Stackable Filter::Line Filter::IRCD);

    my ($filter) = POE::Filter::Stackable->new();
    $filter->push( POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),
		   POE::Filter::IRCD->new(), );

=head1 DESCRIPTION

POE::Filter::IRCD provides a convenient way of parsing and creating IRC protocol
lines. It provides the parsing engine for L<POE::Component::Server::IRC> and L<POE::Component::IRC>.
A standalone version exists as L<Parse::IRC>.

=head1 CONSTRUCTOR

=over

=item new

Creates a new POE::Filter::IRCD object. Takes two optional arguments: 

  'debug', which will print all lines received to STDERR;
  'colonify', set to 1 to force the filter to always colonify the last param passed in a put(),
              default is 0. See below for more detail.

=back

=head1 METHODS

=over

=item get_one_start

=item get_one

=item get_pending

=item get

Takes an arrayref which is contains lines of IRC formatted input. Returns an arrayref of hashrefs
which represents the lines. The hashref contains the following fields:

  prefix
  command
  params ( this is an arrayref )
  raw_line 

For example, if the filter receives the following line, the following hashref is produced:

  LINE: ':moo.server.net 001 lamebot :Welcome to the IRC network lamebot'

  HASHREF: {
		prefix   => ':moo.server.net',
		command  => '001',
		params   => [ 'lamebot', 'Welcome to the IRC network lamebot' ],
		raw_line => ':moo.server.net 001 lamebot :Welcome to the IRC network lamebot',
	   }

=item put

Takes an arrayref containing hashrefs of IRC data and returns an arrayref containing IRC formatted lines.
Optionally, one can specify 'colonify' to override the global colonification option.
eg.

  $hashref = { 
		command => 'PRIVMSG', 
		prefix => 'FooBar!foobar@foobar.com', 
		params => [ '#foobar', 'boo!' ],
		colonify => 1, # Override the global colonify option for this record only.
	      };

  $filter->put( [ $hashref ] );

=item clone

Makes a copy of the filter, and clears the copy's buffer.

=item debug

With a true or false argument, enables or disables debug output respectively. Without an argument the behaviour is to toggle the debug status.

=back

=head1 MAINTAINER

Chris Williams <chris@bingosnet.co.uk>

=head1 AUTHOR

Jonathan Steinert

=head1 LICENSE

Copyright C<(c)> Chris Williams and Jonathan Steinert

This module may be used, modified, and distributed under the same terms as Perl itself. Please see the license that came with your Perl distribution for details.

=head1 SEE ALSO

L<POE>

L<POE::Filter>

L<POE::Filter::Stackable>

L<POE::Component::Server::IRC>

L<POE::Component::IRC>

L<Parse::IRC>

=cut

