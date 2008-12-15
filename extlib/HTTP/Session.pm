package HTTP::Session;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;
use 5.00800;
our $VERSION = '0.27';
use Carp ();
use Scalar::Util ();
use UNIVERSAL::require;

__PACKAGE__->mk_ro_accessors(qw/store state request sid_length/);
__PACKAGE__->mk_accessors(qw/session_id _data is_changed is_fresh/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # check required parameters
    for my $key (qw/store state request/) {
        Carp::croak "missing parameter $key" unless $args{$key};
    }
    # set default values
    $args{_data} ||= {};
    $args{is_changed} ||= 0;
    $args{is_fresh}   ||= 0;
    $args{sid_length} ||= 32;
    $args{id}         ||= 'HTTP::Session::ID::SHA1';
    my $self = bless {%args}, $class;
    $self->_load_session();
    Carp::croak "[BUG] we have bug" unless $self->{request};
    $self;
}

sub _load_session {
    my $self = shift;

    my $session_id = $self->state->get_session_id($self->request);
    if ( $session_id ) {
        my $data = $self->store->select($session_id);
        if ($data) {
            $self->session_id( $session_id );
            $self->_data($data);
        } else {
            if ($self->state->permissive) {
                $self->session_id( $session_id );
                $self->is_fresh(1);
            } else {
                # session was expired? or session fixation?
                # regen session id.
                $self->session_id( $self->_generate_session_id($self->request) );
                $self->is_fresh(1);
            }
        }
    } else {
        # no sid; generate it
        $self->session_id( $self->_generate_session_id($self->request) );
        $self->is_fresh(1);
    }
}

sub _generate_session_id {
    my $self = shift;
    $self->{id}->require or die $@;
    $self->{id}->generate_id($self->sid_length);
}

sub response_filter {
    my ($self, $response) = @_;
    Carp::croak "missing response" unless Scalar::Util::blessed $response;

    $self->state->response_filter($self->session_id, $response);
}

sub finalize {
    my ($self, ) = @_;

    if ($self->is_fresh) {
        $self->store->insert( $self->session_id, $self->_data );
    } else {
        if ($self->is_changed) {
            $self->store->update( $self->session_id, $self->_data );
        }
    }

    delete $self->{$_} for keys %$self;
    bless $self, 'HTTP::Session::Finalized';
}

sub DESTROY {
    my $self = shift;

    if ($self->{store}) {
        $self->finalize();
    } else {
        # this case happen at global destruction?
        Carp::carp "you should call HTTP::Session->finalize method manually";
    }
}

sub keys {
    my $self = shift;
    return keys %{ $self->_data };
}

sub get {
    my ($self, $key) = @_;
    $self->_data->{$key};
}

sub set {
    my ($self, $key, $val) = @_;
    $self->is_changed(1);
    $self->_data->{$key} = $val;
}

sub remove {
    my ( $self, $key ) = @_;
    $self->is_changed(1);
    delete $self->_data->{$key};
}

sub as_hashref {
    my $self = shift;
    return { %{ $self->_data } }; # shallow copy
}

sub expire {
    my $self = shift;
    $self->store->delete($self->session_id);

    # XXX tricky bit to unlock
    delete $self->{$_} for qw(is_fresh is_changed);
    $self->DESTROY;

    # rebless to null class
    bless $self, 'HTTP::Session::Expired';
}

sub regenerate_session_id {
    my ($self, $delete_old) = @_;
    $self->_data( { %{ $self->_data } } );

    if ($delete_old) {
        my $oldsid = $self->session_id;
        $self->store->delete($oldsid);
    }
    my $session_id = $self->_generate_session_id();
    $self->session_id( $session_id );
    $self->is_fresh(1);
}

BEGIN {
    no strict 'refs';
    for my $meth (qw/redirect_filter header_filter html_filter/) {
        *{__PACKAGE__ . '::' . $meth} = sub {
            my ($self, $stuff) = @_;
            if ($self->state->can($meth)) {
                $self->state->$meth($self->session_id, $stuff);
            } else {
                $stuff;
            }
        };
    }
}

package HTTP::Session::Finailzed;
sub is_fresh { 0 }
sub AUTOLOAD { }

package HTTP::Session::Expired;
sub is_fresh { 0 }
sub AUTOLOAD { }

1;
__END__

=encoding utf8

=head1 NAME

HTTP::Session - simple session

=head1 SYNOPSIS

    use HTTP::Session;

    my $session = HTTP::Session->new(
        store   => HTTP::Session::Store::Memcached->new(
            memd => Cache::Memcached->new({
                servers => ['127.0.0.1:11211'],
            }),
        ),
        state   => HTTP::Session::State::Cookie->new(
            cookie_key => 'foo_sid'
        ),
        request => $c->req,
    );

=head1 DESCRIPTION

Yet another session manager.

easy to integrate with L<HTTP::Engine> =)

=head1 METHODS

=over 4

=item $session->load_session()

load session

=item $session->html_filter($html)

filtering HTML

=item $session->redirect_filter($url)

filtering redirect URL

=item $session->header_filter($res)

filtering header

=item $session->response_filter($res)

filtering response. this method runs html_filter, redirect_filter and header_filter.

=item $session->keys()

keys of session.

=item $session->get(key)

get session item

=item $session->set(key, val)

set session item

=item $session->remove(key)

remove item.

=item $session->as_hashref()

session as hashref.

=item $session->expire()

expire the session

=item $session->regenerate_session_id([$delete_old])

regenerate session id.remove old one when $delete_old is true value.

=item $session->finalize()

commit the session data.

=item BUILD

internal use only

=back

=head1 CLEANUP SESSION

Some storage doesn't care the old session data.Please call $store->cleanup( $min ); manually.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 THANKS TO

    kazuhooku
    amachang
    walf443

=head1 SEE ALSO

L<Catalyst::Plugin::Session>, L<Sledge::Session>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
