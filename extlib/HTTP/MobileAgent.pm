package HTTP::MobileAgent;

use strict;
use vars qw($VERSION);
$VERSION = '0.27';

use HTTP::MobileAgent::Request;

require HTTP::MobileAgent::DoCoMo;
require HTTP::MobileAgent::JPhone;
require HTTP::MobileAgent::EZweb;
require HTTP::MobileAgent::AirHPhone;
require HTTP::MobileAgent::NonMobile;
require HTTP::MobileAgent::Display;

use vars qw($MobileAgentRE);
# this matching should be robust enough
# detailed analysis is done in subclass's parse()
my $DoCoMoRE = '^DoCoMo/\d\.\d[ /]';
my $JPhoneRE = '^(?i:J-PHONE/\d\.\d)';
my $VodafoneRE = '^Vodafone/\d\.\d';
my $VodafoneMotRE = '^MOT-';
my $SoftBankRE = '^SoftBank/\d\.\d';
my $SoftBankCrawlerRE = '^Nokia[^/]+/\d\.\d';
my $EZwebRE  = '^(?:KDDI-[A-Z]+\d+[A-Z]? )?UP\.Browser\/';
my $AirHRE = '^Mozilla/3\.0\((?:WILLCOM|DDIPOCKET)\;';
$MobileAgentRE = qr/(?:($DoCoMoRE)|($JPhoneRE|$VodafoneRE|$VodafoneMotRE|$SoftBankRE|$SoftBankCrawlerRE)|($EZwebRE)|($AirHRE))/;

sub new {
    my($class, $stuff) = @_;
    my $request = HTTP::MobileAgent::Request->new($stuff);

    # parse UA string
    my $ua = $request->get('User-Agent');
    my $sub = 'NonMobile';
    if ($ua =~ /$MobileAgentRE/) {
        $sub = $1 ? 'DoCoMo' : $2 ? 'JPhone' : $3 ? 'EZweb' :  'AirHPhone';
    }

    my $self = bless { _request => $request }, "$class\::$sub";
    $self->parse;
    return $self;
}


sub user_agent {
    my $self = shift;
    $self->get_header('User-Agent');
}

sub get_header {
    my($self, $header) = @_;
    $self->{_request}->get($header);
}

# should be implemented in subclasses
sub parse { die }
sub _make_display { die }

sub name  { shift->{name} }

sub display {
    my $self = shift;
    unless ($self->{display}) {
	$self->{display} = $self->_make_display;
    }
    return $self->{display};
}

# utility for subclasses
sub make_accessors {
    my($class, @attr) = @_;
    for my $attr (@attr) {
	no strict 'refs';
	*{"$class\::$attr"} = sub { shift->{$attr} };
    }
}

sub no_match {
    my $self = shift;
    require Carp;
    Carp::carp($self->user_agent, ": no match. Might be new variants. ",
	       "please contact the author of HTTP::MobileAgent!") if $^W;
}

sub is_docomo  { 0 }
sub is_j_phone { 0 }
sub is_vodafone { 0 }
sub is_softbank { 0 }
sub is_ezweb   { 0 }
sub is_airh_phone { 0 }
sub is_non_mobile { 0 }
sub is_tuka { 0 }

sub is_wap1 {
    my $self = shift;
    $self->is_ezweb && ! $self->is_wap2;
}

sub is_wap2 {
    my $self = shift;
    $self->is_ezweb && $self->xhtml_compliant;
}

sub carrier { undef }
sub carrier_longname { undef }

1;
__END__

=head1 NAME

HTTP::MobileAgent - HTTP mobile user agent string parser

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  my $agent = HTTP::MobileAgent->new(Apache->request);
  # or $agent = HTTP::MobileAgent->new; to get from %ENV
  # or $agent = HTTP::MobileAgent->new($agent_string);

  if ($agent->is_docomo) {
      # or if ($agent->name eq 'DoCoMo')
      # or if ($agent->isa('HTTP::MobileAgent::DoCoMo'))
      # it's NTT DoCoMo i-mode.
      # see what's available in H::MA::DoCoMo
  } elsif ($agent->is_vodafone) {
      # it's Vodafone(J-Phone).
      # see what's available in H::MA::Vodafone
  } elsif ($agent->is_ezweb) {
      # it's KDDI/EZWeb.
      # see what's available in H::MA::EZweb
  } else {
      # may be PC
      # $agent is H::MA::NonMobile
  }

  my $display = $agent->display;	# HTTP::MobileAgent::Display
  if ($display->color) { ... }

=head1 DESCRIPTION

HTTP::MobileAgent parses HTTP_USER_AGENT strings of (mainly Japanese)
mobile HTTP user agents. It'll be useful in page dispatching by user agents.

=head1 METHODS

Here are common methods of HTTP::MobileAgent subclasses. More agent
specific methods are described in each subclasses. Note that some of
common methods are also overrided in some subclasses.

=over 4

=item new

  $agent = HTTP::MobileAgent->new;
  $agent = HTTP::MobileAgent->new($r);	# Apache or HTTP::Request
  $agent = HTTP::MobileAgent->new($ua_string);

parses HTTP headers and constructs HTTP::MobileAgent subclass
instance. If no argument is supplied, $ENV{HTTP_*} is used.

Note that you nees to pass Aapche or HTTP::Requet object to new(), as
some mobile agents put useful information on HTTP headers other than
only C<User-Agent:> (like C<x-jphone-msname> in J-Phone).

=item user_agent

  print "User-Agent: ", $agent->user_agent;

returns User-Agent string.

=item name

  print "name: ", $agent->name;

returns User-Agent name like 'DoCoMo'.

=item is_docomo, is_vodafone(is_j_phone, is_softbank), is_ezweb, is_wap1, is_wap2, is_tuka,is_non_mobile

   if ($agent->is_docomo) { }

returns if the agent is DoCoMo, Vodafone(J-Phone) or EZweb.

=item carrier

  print "carrier: ", $agent->carrier;

=item carrier_longname

  print "carrier_longname: ", $agent->carrier_longname;

=item display

  my $display = $agent->display;

returns HTTP::MobileAgent::Display object. See
L<HTTP::MobileAgent::Display> for details.

=item user_id

  my $user_id = $agent->user_id;

return X-DCMGUID, X-UP-SUBNO or X-JPHONE-UID.

=back

=head1 WARNINGS

Following warnings might be raised when C<$^W> is on.

=over 4

=item "%s: no match. Might be new variants. please contact the author of HTTP::MobileAgent!"

User-Agent: string does not match patterns provided in subclasses. It
may be faked user-agent or a new variant. Feel free to mail me to
inform this.

=back

=head1 NOTE

=over 4

=item "Why not adding this module as an extension of HTTP::BrowserDetect?"

Yep, I tried to do. But the module's code seems hard enough for me to
extend and don't want to bother the author for this mobile-specific
features. So I made this module as a separated one.

=back

=head1 MORE IMPLEMENTATIONS

If you have any idea / request for this module to add new subclass,
I'm open to the discussion or (more preferable) patches. Feel free to
mail me.

=head1 OTHER LANGUAGE BINDINGS

This module is now ported to PHP as Net::UserAgent::Mobile by Atsuhiro
KUBO.  See http://pear.php.net/package-info.php?pacid=180 for details.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt> is the original author and wrote almost all the code.

with contributions of Satoshi Tanimoto E<lt>tanimoto@cpan.orgE<gt> and Yoshiki Kurihara E<lt>kurihara@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 MAIN

=head1 SEE ALSO

L<HTTP::MobileAgent::DoCoMo>, L<HTTP::MobileAgent::Vodafone>, L<HTTP::MobileAgent::JPhone>,
L<HTTP::MobileAgent::EZweb>, L<HTTP::MobileAgent::NonMobile>,
L<HTTP::MobileAgent::Display>, L<HTTP::BrowserDetect>

Reference URL for specification is listed in Pods for each subclass.

=cut
