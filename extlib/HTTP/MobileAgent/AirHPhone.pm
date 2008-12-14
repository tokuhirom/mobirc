package HTTP::MobileAgent::AirHPhone;

use strict;
use vars qw($VERSION);
$VERSION = 0.21;

use base qw(HTTP::MobileAgent);

__PACKAGE__->make_accessors(
    qw(vendor model model_version browser_version cache_size)
);

sub is_airh_phone { 1 }

sub carrier { 'H' }

sub carrier_longname { 'AirH' }

sub parse {
    my $self = shift;
    my $ua = $self->user_agent;
    $ua =~ m!^Mozilla/3\.0\((WILLCOM|DDIPOCKET);(.*)\)! or return $self->no_match;
    $self->{name} = $1;
    @{$self}{qw(vendor model model_version browser_version cache_size)} = split m!/!, $2;
    $self->{cache_size} =~ s/^c//i;
}

sub _make_display {
    # XXX
}

sub user_id {
    # XXX
}

1;
__END__

=head1 NAME

HTTP::MobileAgent::AirHPhone - Air H" Phone implementation

=head1 SYNOPSIS

  use HTTP::MobileAgent;

  local $ENV{HTTP_USER_AGENT} = "Mozilla/3.0(DDIPOCKET;JRC/AH-J3001V,AH-J3002V/1.0/0100/c50)CNF/2.0";
  my $agent = HTTP::MobileAgent->new;

  printf "Name: %s\n", $agent->name;		# DDIPOCKET
  printf "Vendor: %s\n", $agent->vendor;        # JRC
  printf "Model: %s\n", $agent->model;          # AH-J3001V,AH-J3002V 
  printf "Model Version: %s\n", $agent->model_version;	# 1.0
  printf "Browser Version: %s\n", $agent->browser_version;	# 0100
  printf "Cache Size: %s\n", $agent->cache_size; # 50

=head1 DESCRIPTION

HTTP::MobileAgent::AirHPhone is a subclass of HTTP::MobileAgent, which
implements DDIPocket's Air H" Phone user agents.

=head1 METHODS

See L<HTTP::MobileAgent/"METHODS"> for common methods. Here are
HTTP::MobileAgent::AirHPhone specific methods.

=over 4

=item vendor

  $vendor = $agent->vendor;

returns vendor name.

=item model

  $model = $agent->model;

returns model name. Note that model names are separated with ','.

=item model_version

  $model_ver = $agent->model_version;

returns version number of the model.

=item browser_version

  $browser_ver = $agent->browser_version;

returns versino number of the browser.

=item cache_size

  $cache_size = $agent->cache_size;

returns cache size with kilobyte unit.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::MobileAgent>

http://www.ddipocket.co.jp/airh_phone/i_hp.html

=cut
