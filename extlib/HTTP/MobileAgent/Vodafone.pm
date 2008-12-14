package HTTP::MobileAgent::Vodafone;

use strict;
use vars qw($VERSION);
$VERSION = 0.21;

use base qw(HTTP::MobileAgent);

__PACKAGE__->make_accessors(
    qw(name version model type packet_compliant
       serial_number vendor vendor_version java_info)
);

sub is_j_phone { shift->is_vodafone }

sub is_vodafone { 1 }

sub is_softbank { shift->is_vodafone }

sub carrier { 'V' }

sub carrier_longname { 'Vodafone' }

sub is_type_c   { shift->{type} =~ /^C/ }
sub is_type_p   { shift->{type} =~ /^P/ }
sub is_type_w   { shift->{type} =~ /^W/ }
sub is_type_3gc { shift->{type} eq '3GC' }

sub parse {
    my $self = shift;

    return $self->_parse_3gc if($self->user_agent =~ /^Vodafone/);
    return $self->_parse_softbank_3gc if($self->user_agent =~ /^SoftBank/);
    return $self->_parse_motorola_3gc if($self->user_agent =~ /^MOT-/);
    return $self->_parse_crawler if($self->user_agent =~ /^Nokia/); # ad hoc

    my($main, @rest) = split / /, _subtract_ua($self->user_agent);

    if (@rest) {
        # J-PHONE/4.0/J-SH51/SNJSHA3029293 SH/0001aa Profile/MIDP-1.0 Configuration/CLDC-1.0 Ext-Profile/JSCL-1.1.0
        $self->{packet_compliant} = 1;
        @{$self}{qw(name version model serial_number)} = split m!/!, $main;
        if ($self->{serial_number}) {
            $self->{serial_number} =~ s/^SN// or return $self->no_match;
        }

        my $vendor = shift @rest;
        @{$self}{qw(vendor vendor_version)} = split m!/!, $vendor;

        my %java_info = map split(m!/!), @rest;
        $self->{java_info} = \%java_info;
    } else {
        # J-PHONE/2.0/J-DN02
        @{$self}{qw(name version model)} = split m!/!, $main;
        $self->{name} = 'J-PHONE' if $self->{name} eq 'J-Phone'; # for J-Phone/5.0/J-SH03 (YahooSeeker)
        $self->{vendor} = ($self->{model} =~ /J-([A-Z]+)/)[0] if $self->{model};
    }

    if ($self->version =~ /^2\./) {
        $self->{type} = 'C2';
    } elsif ($self->version =~ /^3\./) {
        if ($self->get_header('x-jphone-java')) {
            $self->{type} = 'C4';
        } else {
            $self->{type} = 'C3';
        }
    } elsif ($self->version =~ /^4\./) {
        my($jscl_ver) = ($self->{java_info}->{'Ext-Profile'} =~ /JSCL-(\d.+)/);

        if ($jscl_ver =~ /^1\.1\./) {
            $self->{type} = 'P4';
        } elsif ($jscl_ver eq '1.2.1') {
            $self->{type} = 'P5';
        } elsif ($jscl_ver eq '1.2.2') {
            $self->{type} = 'P6';
        } else {
            $self->{type} = 'P7';
        }
    } elsif ($self->version =~ /^5\./) {
        $self->{type} = 'W';
    }
}

# for 3gc
sub _parse_3gc {
    my $self = shift;

    # Vodafone/1.0/V802SE/SEJ001 Browser/SEMC-Browser/4.1 Profile/MIDP-2.0 Configuration/CLDC-1.1
    # Vodafone/1.0/V702NK/NKJ001 Series60/2.6 Profile/MIDP-2.0 Configuration/CLDC-1.1
    # SoftBank/1.0/910T/TJ001 Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1
    my($main, @rest) = split / /, $self->user_agent;
    $self->{packet_compliant} = 1;
    $self->{type} = '3GC';

    @{$self}{qw(name version model _maker serial_number)} = split m!/!, $main;
    if ($self->{serial_number}) {
        $self->{serial_number} =~ s/^SN// or return $self->no_match;
    }

    my($java_info) = $self->user_agent =~ /(Profile.*)$/;
    my %java_info = map split(m!/!), split / /,$java_info;
    $self->{java_info} = \%java_info;
}

# for softbank 3gc
*_parse_softbank_3gc = \&_parse_3gc;

# for motorola 3gc
sub _parse_motorola_3gc{
    my $self = shift;
    my($main, @rest) = split / /, $self->user_agent;

    #MOT-V980/80.2B.04I MIB/2.2.1 Profile/MIDP-2.0 Configuration/CLDC-1.1

    $self->{packet_compliant} = 1;
    $self->{type} = '3GC';

    @{$self}{qw(name)} = split m!/!, $main;

    shift @rest;
    my %java_info = map split(m!/!), @rest;
    $self->{java_info} = \%java_info;

    $self->{model} = 'V702MO'  if $self->{name} eq 'MOT-V980';
    $self->{model} = 'V702sMO' if $self->{name} eq 'MOT-C980';
    $self->{model} ||= $self->get_header('x-jphone-msname');
}

# for crawler
sub _parse_crawler {
    my $self = shift;
    my($main, @rest) = split / /, _subtract_ua($self->user_agent);

    # Nokia6820/2.0 (4.83) Profile/MIDP-1.0 Configuration/CLDC-1.0
    @{$self}{qw(model)} = split m!/!, $main;
    $self->{name} = 'Vodafone';
    $self->{type} = '3GC';

    shift @rest;
    my %java_info = map split(m!/!), @rest;
    $self->{java_info} = \%java_info;
}

sub _make_display {
    my $self = shift;
    my($width, $height) = split /\*/, $self->get_header('x-jphone-display');

    my($color, $depth);
    if (my $c_str = $self->get_header('x-jphone-color')) {
        ($color, $depth) = $c_str =~ /^([CG])(\d+)$/;
    }

    return HTTP::MobileAgent::Display->new(
        width  => $width,
        height => $height,
        color  => $color eq 'C',
        depth  => $depth,
    );
}

sub _subtract_ua {
    my $user_agent = shift;
    $user_agent =~ s/\s*\(compatible\s*[^\)]+\)//i;
    return $user_agent;
}

sub xhtml_compliant {
    my $self = shift;
    return ($self->is_type_w || $self->is_type_3gc) ? 1 : 0;
}

sub user_id {
    my $self = shift;
    return $self->get_header( 'x-jphone-uid' ) unless $self->is_type_c;
}

1;
__END__


=head1 NAME

HTTP::MobileAgent::Vodafone - Vodafone implementation

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  local $ENV{HTTP_USER_AGENT} = "J-PHONE/2.0/J-DN02";
  my $agent = HTTP::MobileAgent->new;

  printf "Name: %s\n", $agent->name;        # "J-PHONE"
  printf "Version: %s\n", $agent->version;  # 2.0
  printf "Model: %s\n", $agent->model;      # "J-DN02"
  print  "Packet is compliant.\n" if $agent->packet_compliant; # false

  # only availabe in Java compliant
  # e.g.) "J-PHONE/4.0/J-SH51/SNXXXXXXXXX SH/0001a Profile/MIDP-1.0 Configuration/CLDC-1.0 Ext-Profile/JSCL-1.1.0"
  printf "Serial: %s\n", $agent->serial_number; # XXXXXXXXXX
  printf "Vendor: %s\n", $agent->vendor;        # 'SH'
  printf "Vender Version: %s\n", $agent->vendor_version; # "0001a"

  my $info = $self->java_info;      # hash reference
  print map { "$_: $info->{$_}\n" } keys %$info;

=head1 DESCRIPTION

HTTP::MobileAgent::Vodafone is a subclass of HTTP::MobileAgent, which
implements Vodafone(J-Phone) user agents.

=head1 METHODS

See L<HTTP::MobileAgent/"METHODS"> for common methods. Here are
HTTP::MobileAgent::Vodafone specific methods.

=over 4

=item version

  $version = $agent->version;

returns Vodafone version number like '1.0'.

=item model

  $model = $agent->model;

returns name of the model like 'J-DN02'.

=item packet_compliant

  if ($agent->packet_compliant) { }

returns whether the agent is packet connection complicant or not.

=item serial_number

  $serial_number = $agent->serial_number;

return terminal unique serial number. returns undef if user forbids to
send his/her serial number.

=item vendor

  $vendor = $agent->vendor;

returns vendor code like 'SH'.

=item vendor_version

  $vendor_version = $agent->vendor_version;

returns vendor version like '0001a'.  returns undef if unknown,

=item type

   if ($agent->type eq 'C2') { }

returns the type, which is one of the following: C2 C3 C4 P4 P5 P6 P7 W 3GC

=item is_type_c,is_type_p,is_type_w,is_type_3gc

   if ($agent->is_type_c) { }

returns if the type is C, P or W.

=item java_info

  $info = $agent->java_info;

returns hash reference of Java profiles. Hash structure is something like:

  'Profile'       => 'MIDP-1.0',
  'Configuration' => 'CLDC-1.0',
  'Ext-Profile'   => 'JSCL-1.1.0',

returns undef if unknown.

=item xhtml_compliant

  if ($agent->xhtml_compliant) { }

returns if the agent is XHTML compliant.

=back

=head1 TODO

=over 4

=item *

Area information support on http://www.dp.j-phone.com/jsky/position.html

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::MobileAgent>

http://www.dp.j-phone.com/jsky/user.html

http://www.dp.j-phone.com/jsky/position.html


=cut
