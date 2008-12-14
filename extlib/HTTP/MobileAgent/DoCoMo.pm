package HTTP::MobileAgent::DoCoMo;

use strict;
use vars qw($VERSION);
$VERSION = 0.19;

use base qw(HTTP::MobileAgent);

__PACKAGE__->make_accessors(
    qw(version model status bandwidth
       serial_number is_foma card_id xhtml_compliant comment)
);

use HTTP::MobileAgent::DoCoMoDisplayMap qw($DisplayMap);

# various preferences
use vars qw($DefaultCacheSize $HTMLVerMap $GPSModels);
$DefaultCacheSize = 5;

# http://www.nttdocomo.co.jp/service/imode/make/content/spec/useragent/
$HTMLVerMap = [
    # regex => version
    qr/[DFNP]501i/ => '1.0',
    qr/502i|821i|209i|691i|(F|N|P|KO)210i|^F671i$/ => '2.0',
    qr/(D210i|SO210i)|503i|211i|SH251i|692i|200[12]|2101V/ => '3.0',
    qr/504i|251i|^F671iS$|^F661i$|^F672i$|212i|SO213i|2051|2102V|2701|850i/ => '4.0',
    qr/eggy|P751v/ => '3.2',
    qr/505i|506i|252i|253i|P213i|600i|700i|701i|800i|880i|SH851i|P851i|881i|900i|901i/ => '5.0',
    qr/702i|D851iWM|902i/ => '6.0',
];

$GPSModels = { map { $_ => 1 } qw(F661i F505iGPS) };

sub is_docomo { 1 }

sub carrier { 'I' }

sub carrier_longname { 'DoCoMo' }

sub parse {
    my $self = shift;
    my($main, $foma_or_comment) = split / /, $self->user_agent, 2;

    if ($foma_or_comment && $foma_or_comment =~ s/^\((.*)\)$/$1/) {
	# DoCoMo/1.0/P209is (Google CHTML Proxy/1.0)
	$self->{comment} = $1;
	$self->_parse_main($main);
    } elsif ($foma_or_comment) {
	# DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)
	$self->{is_foma} = 1;
	@{$self}{qw(name version)} = split m!/!, $main;
	$self->_parse_foma($foma_or_comment);
    } else {
	# DoCoMo/1.0/R692i/c10
	$self->_parse_main($main);
    }

    $self->{xhtml_compliant} =
      ( $self->is_foma && !( $self->html_version && $self->html_version == 3.0 ) )
      ? 1
      : 0;
}

sub _parse_main {
    my($self, $main) = @_;
    my($name, $version, $model, $cache, @rest) = split m!/!, $main;
    $self->{name}    = $name;
    $self->{version} = $version;
    $self->{model}   = $model;
    $self->{model}   = 'SH505i' if $self->{model} eq 'SH505i2';

    if ($cache) {
	$cache =~ s/^c// or return $self->no_match;
	$self->{cache_size} = $cache;
    }

    for (@rest) {
	/^ser(\w{11})$/  and do { $self->{serial_number} = $1; next };
	/^(T[CDBJ])$/    and do { $self->{status} = $1; next };
	/^s(\d+)$/       and do { $self->{bandwidth} = $1; next };
	/^W(\d+)H(\d+)$/ and do { $self->{display_bytes} = "$1*$2"; next; };
    }
}

sub _parse_foma {
    my($self, $foma) = @_;

    $foma =~ s/^([^\(]+)// or return $self->no_match;
    $self->{model} = $1;
    $self->{model} = 'SH2101V' if $1 eq 'MST_v_SH2101V'; # Huh?

    if ($foma =~ s/^\((.*?)\)$//) {
	my @options = split /;/, $1;
	for (@options) {
	    /^c(\d+)$/       and $self->{cache_size} = $1, next;
	    /^ser(\w{15})$/  and $self->{serial_number} = $1, next;
	    /^icc(\w{20})$/  and $self->{card_id} = $1, next;
	    /^(T[CDBJ])$/    and $self->{status} = $1, next;
            /^W(\d+)H(\d+)$/ and $self->{display_bytes} = "$1*$2", next;
	    $self->no_match;
	}
    }
}

sub html_version {
    my $self = shift;

    my @map = @$HTMLVerMap;
    while (my($re, $version) = splice(@map, 0, 2)) {
	return $version if $self->model =~ /$re/;
    }
    return undef;
}

sub cache_size {
    my $self = shift;
    return $self->{cache_size} || $DefaultCacheSize;
}

sub series {
    my $self = shift;
    my $model = $self->model;

    if ($self->is_foma && $model =~ /\d{4}/) {
        return 'FOMA';
    }

    $model =~ /(\d{3}i)/;
    return $1;
}

sub vendor {
    my $self = shift;
    my $model = $self->model;
    $model =~ /^([A-Z]+)\d/;
    return $1;
}

sub _make_display {
    my $self = shift;
    my $display = $DisplayMap->{uc($self->model)};
    if ($self->{display_bytes}) {
	my($w, $h) = split /\*/, $self->{display_bytes};
	$display->{width_bytes}  = $w;
	$display->{height_bytes} = $h;
    }
    return HTTP::MobileAgent::Display->new(%$display);
}

sub is_gps {
    my $self = shift;
    return exists $GPSModels->{$self->model};
}

sub user_id {
    my $self = shift;
    return $self->get_header( 'x-dcmguid' );
}

1;
__END__

=head1 NAME

HTTP::MobileAgent::DoCoMo - NTT DoCoMo implementation

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  local $ENV{HTTP_USER_AGENT} = "DoCoMo/1.0/P502i/c10";
  my $agent = HTTP::MobileAgent->new;

  printf "Name: %s\n", $agent->name;       		# "DoCoMo"
  printf "Ver: %s\n", $agent->version; 			# 1.0
  printf "HTML ver: %s\n", $agent->html_version;	# 2.0
  printf "Model: %s\n", $agent->model;			# "P502i"
  printf "Cache: %dk\n", $agent->cache_size;		# 10
  print  "FOMA\n" if $agent->is_foma;			# false
  printf "Vendor: %s\n", $agent->vendor;		# 'P'
  printf "Series: %s\n", $agent->series;		# "502i"

  # only available with <form utn>
  # e.g.) "DoCoMo/1.0/P503i/c10/serNMABH200331";
  printf "Serial: %s\n", $agent->serial_number;		# "NMABH200331"

  # e.g.) "DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)";
  printf "Serial: %s\n", $agent->serial_number;		# "0123456789abcde"
  printf "Card ID: %s\n", $agent->card_id;		# "01234567890123456789"

  # e.g.) "DoCoMo/1.0/P502i (Google CHTML Proxy/1.0)"
  printf "Comment: %s\n", $agent->comment;		# "Google CHTML Proxy/1.0

  # e.g.) "DoCoMo/1.0/D505i/c20/TB/W20H10"
  printf "Status: %s\n", $agent->status;                # "TB"

  # only available in eggy/M-stage
  # e.g.) "DoCoMo/1.0/eggy/c300/s32/kPHS-K"
  printf "Bandwidth: %dkbps\n", $agent->bandwidth;	# 32

  # e.g.) "DoCoMo/2.0 SO902i(c100;TB;W30H16)"
  print "XHTML compiant!\n" if $agent->xhtml_compliant;	# true

=head1 DESCRIPTION

HTTP::MobileAgent::DoCoMo is a subclass of HTTP::MobileAgent, which
implements NTT docomo i-mode user agents.

=head1 METHODS

See L<HTTP::MobileAgent/"METHODS"> for common methods. Here are
HTTP::MobileAgent::DoCoMo specific methods.

=over 4

=item version

  $version = $agent->version;

returns DoCoMo version number like "1.0".

=item html_version

  $html_version = $agent->html_version;

returns supported HTML version like '3.0'. retuns undef if unknown.

=item model

  $model = $agent->model;

returns name of the model like 'P502i'.

=item cache_size

  $cache_size = $agent->cache_size;

returns cache size as killobytes unit. returns 5 if unknown.

=item is_foma

  if ($agent->is_foma) { }

retuns whether it's FOMA or not.

=item vendor

  $vendor = $agent->vendor;

returns vender code like 'SO' for Sony. returns undef if unknown.

=item series

  $series = $agent->series;

returns series name like '502i'. returns undef if unknown.

=item serial_number

  $serial_number = $agent->serial_number;

returns hardware unique serial number (15 digit in FOMA, 11 digit
otherwise alphanumeric). Only available with E<lt>form utnE<gt>
attribute. returns undef otherwise.

=item card_id

  $card_id = $agent->card_id;

returns FOMA Card ID (20 digit alphanumeric). Only available in FOMA
with E<lt>form utnE<gt> attribute. returns undef otherwise.

=item comment

  $comment = $agent->comment;

returns comment on user agent string like 'Google Proxy'. returns
undef otherwise.

=item bandwidth

  $bandwidth = $agent->bandwidth;

returns bandwidth like 32 as killobytes unit. Only vailable in eggy,
returns undef otherwise.

=item status

  $status = $agent->status;

returns status like "TB", "TC", "TD" or "TJ", which means:

  TB | Browsers
  TC | Browsers with image off (only Available in HTML 5.0)
  TD | Fetching JAR
  TJ | i-Appli

=item xhtml_compliant

  if ($agent->xhtml_compliant) { }

returns if the agent is XHTML compliant.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::MobileAgent>

http://www.nttdocomo.co.jp/p_s/imode/spec/useragent.html

http://www.nttdocomo.co.jp/p_s/imode/spec/ryouiki.html

http://www.nttdocomo.co.jp/p_s/imode/tag/utn.html

http://www.nttdocomo.co.jp/p_s/mstage/visual/contents/cnt_mpage.html


=cut
