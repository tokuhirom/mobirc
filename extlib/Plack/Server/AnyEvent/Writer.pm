package Plack::Server::AnyEvent::Writer;

use strict;
use warnings;

use AnyEvent::Handle;

sub new {
    my ( $class, $socket, $done ) = @_;

    bless { handle => AnyEvent::Handle->new( fh => $socket ), done => $done }, $class;
}

sub poll_cb {
    my ( $self, $cb ) = @_;

    my $handle = $self->{handle};

    if ( $cb ) {
        # notifies that now is a good time to ->write
        $handle->on_drain(sub {
            do {
                if ( $self->{in_poll_cb} ) {
                    $self->{poll_again}++;
                    return;
                } else {
                    local $self->{in_poll_cb} = 1;
                    $cb->($self);
                }
            } while ( delete $self->{poll_again} );
        });

        # notifies of client close
        $handle->on_error(sub {
            my $err = $_[2];
            $handle->destroy;
            $cb->(undef, $err);
        });
    } else {
        $handle->on_drain;
        $handle->on_error;
    }
}

sub write { $_[0]{handle}->push_write($_[1]) }

sub close {
    my $self = shift;

    my $handle = $self->{handle};
    my $done = $self->{done};

    if ($handle->{fh}) {
        my $close_cb = sub {
            $handle->destroy;
            $done->send;
        };

        $handle->on_drain($close_cb);
        $handle->on_error($close_cb);
        $handle->wtimeout(60);
    } else {
        #already closed
        $done->send;
    }
}

sub DESTROY { $_[0]->close }

# ex: set sw=4 et:

1;
__END__
