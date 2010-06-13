package HTTP::Session::State::MobileAgentID;
use HTTP::Session::State::Base;
use HTTP::MobileAgent;
use Net::CIDR::MobileJP;

__PACKAGE__->mk_ro_accessors(qw/mobile_agent check_ip cidr/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # check required parameters
    for (qw/mobile_agent/) {
        Carp::croak "missing parameter $_" unless $args{$_};
    }
    # set default values
    $args{check_ip} = exists($args{check_ip}) ? $args{check_ip} : 1;
    $args{permissive} = exists($args{permissive}) ? $args{permissive} : 1;
    $args{cidr}       = exists($args{cidr}) ? $args{cidr} : Net::CIDR::MobileJP->new();
    bless {%args}, $class;
}

sub _get_id {
    my ($ma, ) = @_;
    my $key = {
        'V' => 'x-jphone-uid',
        'E' => 'x-up-subno',
        'I' => 'x-dcmguid',
    }->{$ma->carrier};
    return $ma->get_header($key);
}

sub get_session_id {
    my ($self, $req) = @_;

    my $ma = $self->mobile_agent;
    Carp::croak "this module only supports docomo/softbank/ezweb" unless $ma->is_docomo || $ma->is_softbank || $ma->is_ezweb;

    my $id = _get_id($ma);
    if ($id) {
        if ($self->check_ip) {
            my $ip = $ENV{REMOTE_ADDR} || (Scalar::Util::blessed($req) ? $req->address : $req->{REMOTE_ADDR}) || die "cannot get client ip address";
            if ($self->cidr->get_carrier($ip) ne $ma->carrier) {
                die "SECURITY: invalid ip($ip, $ma, $id)";
            }
        }
        return $id;
    } else {
        die "cannot detect mobile id from: $ma";
    }
}

sub response_filter { }

1;
__END__

=head1 NAME

HTTP::Session::State::MobileAgentID - Maintain session IDs using mobile phone's unique id

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::MobileAgentID->new(
            mobile_agent => HTTP::MobileAgent->new($r),
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

Maintain session IDs using mobile phone's unique id

=head1 CONFIGURATION

=over 4

=item mobile_agent

instance of L<HTTP::MobileAgent>

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

=head1 SEE ALSO

L<HTTP::Session>
