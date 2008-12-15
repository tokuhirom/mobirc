package Net::CIDR::MobileJP;
use strict;
use warnings;
use 5.00800;
use Carp;
use Net::CIDR::Lite;
use File::ShareDir ();
our $VERSION = '0.16';

our $yaml_loader;
BEGIN {
    $yaml_loader = sub {
        ## no critic
        if (eval "use YAML::Syck; 1;") {
            \&YAML::Syck::LoadFile;
        } else {
            require YAML;
            \&YAML::LoadFile;
        }
    }->();
};

sub new {
    my ($class, $stuff) = @_;

    return bless {spanner => $class->_create_spanner($class->_load_config($stuff))}, $class;
}

sub _create_spanner {
    my ($class, $conf) = @_;

    my $spanner = Net::CIDR::Lite::Span->new;
    while (my ($carrier, $ip_ranges) = each %$conf) {
        $spanner->add(do {
            my $cidr = Net::CIDR::Lite->new;
            for my $ip_range (@$ip_ranges) {
                $cidr->add($ip_range);
            }
            $cidr;
        }, $carrier);
    }
    return $spanner;
}

sub _load_config {
    my ($self, $stuff) = @_;

    my $data;
    if (defined $stuff && -f $stuff && -r _) {
        # load yaml from file
        $data = $yaml_loader->($stuff);
    } elsif ($stuff) {
        # raw data
        $data = $stuff;
    } else {
        # generated file
        $data = $yaml_loader->(File::ShareDir::module_file('Net::CIDR::MobileJP', 'cidr.yaml'));
    }
    return $data;
}

sub get_carrier {
    my ($self, $ip) = @_;

    my ($carrier,) =  map { keys %$_ } values %{$self->{spanner}->find($ip)};
    return $carrier || 'N';
}


1;
__END__

=head1 NAME

Net::CIDR::MobileJP - mobile ip address in Japan

=head1 SYNOPSIS

    use Net::CIDR::MobileJP;
    my $cidr = Net::CIDR::MobileJP->new('net-cidr-mobile-jp.yaml');
    $cidr->get_carrier('222.7.56.248');
    # => 'E'

=head1 DESCRIPTION

Net::CIDR::MobileJP is an utility to detect an ip address is mobile (cellular) ip address or not.

=head1 METHODS

=head2 new

    my $cidr = Net::CIDR::MobileJP->new('net-cidr-mobile-jp.yaml');  # from yaml
    my $cidr = Net::CIDR::MobileJP->new({E => ['59.135.38.128/25'], ...});

create new instance.

The argument is 'path to yaml' or 'raw data'.

=head2 get_carrier

    $cidr->get_carrier('222.7.56.248');

Get the career name from IP address.

Carrier name is compatible with L<HTTP::MobileAgent>.

=head1 AUTHORS

  Tokuhiro Matsuno  C<< <tokuhiro __at__ mobilefactory.jp> >>
  Jiro Nishiguchi

=head1 THANKS TO

  Tatsuhiko Miyagawa
  Masayoshi Sekimura
  HIROSE, Masaaki

=head1 SEE ALSO

L<http://d.hatena.ne.jp/spiritloose/20061010/1160471510>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.
