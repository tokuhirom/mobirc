package HTTP::Session::State::MobileAttributeID;
use strict;
use warnings;
use HTTP::Session::State::Base;
use HTTP::MobileAttribute  plugins => [
    'UserID',
    'CIDR',
];
use 5.00800;
our $VERSION = '0.37';

__PACKAGE__->mk_ro_accessors(qw/mobile_attribute check_ip/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # check required parameters
    for (qw/mobile_attribute/) {
        Carp::croak "missing parameter $_" unless $args{$_};
    }
    # set default values
    $args{check_ip} = exists($args{check_ip}) ? $args{check_ip} : 1;
    $args{permissive} = exists($args{permissive}) ? $args{permissive} : 1;
    bless {%args}, $class;
}

sub get_session_id {
    my ($self, $req) = @_;

    my $ma = $self->mobile_attribute;
    if ($ma->can('user_id')) {
        if (my $user_id = $ma->user_id) {
            if ($self->check_ip) {
                my $ip = $ENV{REMOTE_ADDR} || (Scalar::Util::blessed($req) ? $req->address : $req->{REMOTE_ADDR}) || die "cannot get address";
                if (!$ma->isa_cidr($ip)) {
                    die "SECURITY: invalid ip($ip, $ma, $user_id)";
                }
            }
            return $user_id;
        } else {
            die "cannot detect mobile id from $ma";
        }
    } else {
        die "this carrier doesn't supports user_id: $ma";
    }
}

sub response_filter { }



1;
__END__

=encoding utf8

=head1 NAME

HTTP::Session::State::MobileAttributeID - Maintain session IDs using mobile phone's unique id

=head1 SYNOPSIS

    use HTTP::Session::State::MobileAttribute;
    use HTTP::Session;

    HTTP::Session->new(
        state => HTTP::Session::State::MobileAttributeID->new(
            mobile_attribute => HTTP::MobileAttribute->new($r),
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

Maintain session IDs using mobile phone's unique id

B<THIS MODULE MAKES SECURITY HOLE. TAKE CAREFULLY.>.

=head1 CONFIGURATION

=over 4

=item mobile_attribute

instance of L<HTTP::MobileAttribute>

=item check_ip

check the IP address in the carrier's cidr/ or not?
see also L<Net::CIDR::MobileJP>

=back

=head1 METHODS

=over 4

=item get_session_id

=item response_filter

for internal use only

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

L<HTTP::Session>, L<HTTP::MobileAttribute>, L<http://www.hash-c.co.jp/info/2010052401.html>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
