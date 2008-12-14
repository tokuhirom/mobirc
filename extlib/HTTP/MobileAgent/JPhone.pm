package HTTP::MobileAgent::JPhone;

use strict;
use vars qw($VERSION);
$VERSION = 0.18;

use base qw(HTTP::MobileAgent::Vodafone);

1;
__END__

=head1 NAME

HTTP::MobileAgent::JPhone - J-Phone implementation

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  local $ENV{HTTP_USER_AGENT} = "J-PHONE/2.0/J-DN02";
  my $agent = HTTP::MobileAgent->new;

  printf "Name: %s\n", $agent->name;		# "J-PHONE"
  printf "Version: %s\n", $agent->version;	# 2.0
  printf "Model: %s\n", $agent->model;		# "J-DN02"
  print  "Packet is compliant.\n" if $agent->packet_compliant; # false

  # only availabe in Java compliant
  # e.g.) "J-PHONE/4.0/J-SH51/SNXXXXXXXXX SH/0001a Profile/MIDP-1.0 Configuration/CLDC-1.0 Ext-Profile/JSCL-1.1.0"
  printf "Serial: %s\n", $agent->serial_number; # XXXXXXXXXX
  printf "Vendor: %s\n", $agent->vendor;        # 'SH'
  printf "Vender Version: %s\n", $agent->vendor_version; # "0001a"

  my $info = $self->java_info;		# hash reference
  print map { "$_: $info->{$_}\n" } keys %$info;

=head1 DESCRIPTION

HTTP::MobileAgent::JPhone is a subclass of HTTP::MobileAgent::Vodafone.

=head1 METHODS

See L<HTTP::MobileAgent::Vodafone/"METHODS"> for methods.


=head1 SEE ALSO

L<HTTP::MobileAgent::Vodafone>


=cut
