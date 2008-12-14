package HTTP::MobileAgent::EZweb;

use strict;
use vars qw($VERSION);
$VERSION = 0.20;

use base qw(HTTP::MobileAgent);

__PACKAGE__->make_accessors(
    qw(version model device_id server xhtml_compliant comment)
);

sub is_ezweb { 1 }

sub carrier { 'E' }

sub carrier_longname { 'EZweb' }

sub is_tuka {
  my $self = shift;
  my $tuka = substr($self->device_id, 2, 1);
  if($self->is_wap2){
      return 1 if $tuka eq 'U';
  } else {
      return 1 if $tuka eq 'T';
  }
  return;
}

sub is_win {
  my $self = shift;
  my $win = substr($self->device_id, 2, 1);
  $win eq '3' ? 1 : 0;
}

sub parse {
    my $self = shift;
    my $ua = $self->user_agent;
    if ($ua =~ s/^KDDI\-//) {
	# KDDI-TS21 UP.Browser/6.0.2.276 (GUI) MMP/1.1
	$self->{xhtml_compliant} = 1;
	my($device, $browser, $opt, $server) = split / /, $ua, 4;
	$self->{device_id} = $device;

	my($name, $version) = split m!/!, $browser;
	$self->{name} = $name;
	$self->{version} = "$version $opt";
	$self->{server} = $server;
    }
    else {
	# UP.Browser/3.01-HI01 UP.Link/3.4.5.2
	my($browser, $server, $comment) = split / /, $ua, 3;
	my($name, $software) = split m!/!, $browser;
	$self->{name} = $name;
	@{$self}{qw(version device_id)} = split /-/, $software;
	$self->{server} = $server;
	if ($comment) {
	    $comment =~ s/^\((.*)\)$/$1/;
	    $self->{comment} = $comment;
	}
    }
    $self->{model} = $self->{device_id};
}

sub _make_display {
    my $self = shift;
    my($width, $height) = split /,/, $self->get_header('x-up-devcap-screenpixels');
    my $depth = (split /,/, $self->get_header('x-up-devcap-screendepth'))[0];
    my $color = $self->get_header('x-up-devcap-iscolor');
    return HTTP::MobileAgent::Display->new(
	width  => $width,
	height => $height,
	color  => (defined $color && $color eq '1'),
	depth  => 2 ** $depth,
    );
}

sub user_id {
    my $self = shift;
    return $self->get_header( 'x-up-subno' );
}

1;
__END__

=head1 NAME

HTTP::MobileAgent::EZweb - EZweb implementation

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  local $ENV{HTTP_USER_AGENT} = "UP.Browser/3.01-HI02 UP.Link/3.2.1.2";
  my $agent = HTTP::MobileAgent->new;

  printf "Name: %s\n", $agent->name;		# "UP.Browser"
  printf "Version: %s\n", $agent->version;	# 3.01
  printf "DevieID: %s\n", $agent->device_id;	# HI02
  printf "Server: %s\n", $agent->server;	# "UP.Link/3.2.1.2"

  # e.g.) UP.Browser/3.01-HI02 UP.Link/3.2.1.2 (Google WAP Proxy/1.0)
  printf "Comment: %s\n", $agent->comment;	# "Google WAP Proxy/1.0"

  # e.g.) KDDI-TS21 UP.Browser/6.0.2.276 (GUI) MMP/1.1
  print "XHTML compiant!\n" if $agent->xhtml_compliant;	# true

=head1 DESCRIPTION

HTTP::MobileAgent::EZweb is a subclass of HTTP::MobileAgent, which
implements EZweb (WAP1.0/2.0) user agents.

=head1 METHODS

See L<HTTP::MobileAgent/"METHODS"> for common methods. Here are
HTTP::MobileAgent::EZweb specific methods.

=over 4

=item version

  $version = $agent->version;

returns UP.Browser version number like '3.01'.

=item device_id

  $device_id = $agent->device_id;

returns device ID like 'TS21'.

=item server

  $server = $agent->server;

returns server string like "UP.Link/3.2.1.2".

=item comment

  $comment = $agent->comment;

returns comment like "Google WAP Proxy/1.0". returns undef if nothinng.

=item xhtml_compliant

  if ($agent->xhtml_compliant) { }

returns if the agent is XHTML compliant.

=item is_tuka

  if ($agent->is_tuka) { }

returns if the agent is TU-KA model.

=item is_win

  if ($agent->is_win) { }

returns if the agent is win model.

=back

=head1 TODO

=over 4

=item *

Spec information support listed in
http://www.au.kddi.com/ezfactory/tec/spec/new_win/ezkishu.html

(Patches are always welcome ;))

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::MobileAgent>

http://www.au.kddi.com/ezfactory/tec/spec/4_4.html

http://www.au.kddi.com/ezfactory/tec/spec/new_win/ezkishu.html

=cut
