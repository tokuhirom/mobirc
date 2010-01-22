package Plack::Server::AnyEvent::Reader;
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Util qw(WSAEWOULDBLOCK);
use Errno qw(EAGAIN EINTR);
use Try::Tiny;

sub new {
    my ($class, $sock) = @_;

    bless {
        sock => $sock,
        timeout => undef,
        on_error => sub { die @_ },
        _watcher => undef,
        _timer => undef,
    }, $class;
}

sub _call_cb {
    my $self = shift;
    my $cb = shift;

    undef $self->{_watcher};
    undef $self->{_timer};

    $cb->(@_);
}

sub _error {
    my $self = shift;

    undef $self->{_watcher};
    undef $self->{_timer};
    undef $self->{sock};

    $self->{on_error}->(@_);
}

sub _update_timer {
    my $self = shift;

    return unless defined $self->{timeout};

    $self->{_timer} = AE::timer $self->{timeout}, 0, sub {
        $self->_error('timeout');
    };
}

sub read_headers {
    my ($self, $cb) = @_;

    my $headers = '';

    return if try {
        if ($self->_try_read_headers($headers)) {
            $self->_call_cb($cb, $headers);
            return 1;
        }
    } catch {
        $self->_error($_);
        return 1;
    };

    $self->_update_timer;

    $self->{_watcher} = AE::io $self->{sock}, 0, sub {
        try {
            $self->_update_timer;

            if ($self->_try_read_headers($headers)) {
                $self->_call_cb($cb, $headers);
            }
        } catch {
            $self->_error($_);
        };
    };
}

sub read_chunk {
    my ($self, $size, $cb) = @_;

    my $data = '';

    return if try {
        if ($self->_try_read_chunk($size, $data)) {
            $self->_call_cb($cb, $data);
            return 1;
        }
    } catch {
        $self->_error($_);
        return 1;
    };

    $self->_update_timer;

    $self->{_watcher} = AE::io $self->{sock}, 0, sub {
        try {
            $self->_update_timer;

            if ($self->_try_read_chunk($size, $data)) {
                $self->_call_cb($cb, $data);
            }
        } catch {
            $self->_error($_);
        };
    };
}

sub _try_read_headers {
    my ($self, undef) = @_;

    my $sock = $self->{sock};
    local $/ = "\012";

    READ_MORE: foreach my $headers ($_[1]) {
        my $line = <$sock>;

        if (defined $line) {
            $headers .= $line;

            if ($line eq "\015\012" or $line eq "\012") {
                # got an empty line, we're done reading the headers
                return 1;
            } else {
                # try to read more lines using buffered IO
                redo READ_MORE;
            }
        } else {
            if ($! and $! != EAGAIN && $! != EINTR && $! != WSAEWOULDBLOCK) {
                die $!;
            } elsif (not $!) {
                die "client disconnected";
            }
        }
    }

    # did not read to end of req, wait for more data to arrive
    return;
}

sub _try_read_chunk {
    my ($self, $size, undef) = @_;

    my $sock = $self->{sock};
    my $max_read = 8192;

    READ_MORE: foreach my $data ($_[2]) {
        my $remaining_size = $size - length $data;
        my $read_size = $remaining_size > $max_read ? $max_read : $remaining_size;
        my $len = read($sock, my $buf, $read_size);

        if (defined $len) {
            if ($len > 0) {
                $data .= $buf;
                $remaining_size -= $len;

                if ($remaining_size <= 0) {
                    return 1;
                } else {
                    redo READ_MORE;
                }
            } else {
                return 1;
            }
        } else {
            if ($! and $! != EAGAIN && $! != EINTR && $! != WSAEWOULDBLOCK) {
                die $!;
            }
        }
    }

    # did not read to end of data, wait for more data to arrive
    return;
}

1;
