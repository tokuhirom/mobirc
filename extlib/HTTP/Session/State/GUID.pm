package HTTP::Session::State::GUID;
use strict;
use warnings;
use base qw/HTTP::Session::State::MobileAttributeID/;
use HTML::StickyQuery::DoCoMoGUID;

sub response_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    if ($res->code == 302) {
        if (my $uri = $res->header('Location')) {
            $res->header('Location' => $self->redirect_filter($session_id, $uri));
        }
        return $res;
    } elsif ($res->content) {
        $res->content( $self->html_filter($session_id, $res->content) );
        return $res;
    } else {
        return $res; # nop
    }
}

sub html_filter {
    my ($self, $session_id, $html) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $sticky = HTML::StickyQuery::DoCoMoGUID->new;
    return $sticky->sticky(
        scalarref => \$html,
    );
}

sub redirect_filter {
    my ( $self, $session_id, $path ) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $uri = URI->new($path);
    $uri->query_form( $uri->query_form, guid => 'ON' );
    return $uri->as_string;
}

1;
__END__

=head1 NAME

HTTP::Session::State::GUID - Maintain session IDs using DoCoMo phone's unique id

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::GUID->new(
            mobile_attribute => HTTP::MobileAttribute->new($r),
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

Maintain session IDs using mobile phone's unique id

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

=head1 SEE ALSO

L<HTTP::Session>, L<HTML::StickyQuery::DoCoMoGUID>

