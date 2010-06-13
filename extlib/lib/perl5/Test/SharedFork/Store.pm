package Test::SharedFork::Store;
use strict;
use warnings;
use Storable ();
use Fcntl ':seek', ':DEFAULT', ':flock';
use File::Temp ();
use IO::Handle;

sub new {
    my $class = shift;
    my %args = @_;
    my $filename = File::Temp::tmpnam();
    my $self = bless {callback_on_open => $args{cb}, filename => $filename, lock => 0, pid => $$, ppid => $$}, $class;
    $self->open();

    # initialize
    Storable::nstore_fd(+{
        array => [],
        scalar => 0,
    }, $self->{fh}) or die "Cannot write initialize data to $filename";

    return $self;
}

sub open {
    my $self = shift;
    if (my $cb = $self->{callback_on_open}) {
        $cb->($self);
    }
    sysopen my $fh, $self->{filename}, O_RDWR|O_CREAT or die $!;
    $fh->autoflush(1);
    $self->{fh} = $fh;
}

sub close {
    my $self = shift;
    close $self->{fh};
    undef $self->{fh};
}

sub get {
    my ($self, $key) = @_;

    $self->_reopen_if_needed;
    my $ret = $self->lock_cb(sub {
        $self->get_nolock($key);
    }, LOCK_SH);
    return $ret;
}

sub get_nolock {
    my ($self, $key) = @_;
    $self->_reopen_if_needed;
    seek $self->{fh}, 0, SEEK_SET or die $!;
    Storable::fd_retrieve($self->{fh})->{$key};
}

sub set {
    my ($self, $key, $val) = @_;

    $self->_reopen_if_needed;
    $self->lock_cb(sub {
        $self->set_nolock($key, $val);
    }, LOCK_EX);
}

sub set_nolock {
    my ($self, $key, $val) = @_;

    $self->_reopen_if_needed;

    seek $self->{fh}, 0, SEEK_SET or die $!;
    my $dat = Storable::fd_retrieve($self->{fh});
    $dat->{$key} = $val;

    truncate $self->{fh}, 0;
    seek $self->{fh}, 0, SEEK_SET or die $!;
    Storable::nstore_fd($dat => $self->{fh}) or die "Cannot store data to $self->{filename}";
}

sub lock_cb {
    my ($self, $cb) = @_;

    $self->_reopen_if_needed;

    if ($self->{lock}++ == 0) {
        flock $self->{fh}, LOCK_EX or die $!;
    }

    my $ret = $cb->();

    $self->{lock}--;
    if ($self->{lock} == 0) {
        flock $self->{fh}, LOCK_UN or die $!;
    }

    $ret;
}

sub _reopen_if_needed {
    my $self = shift;
    if ($self->{pid} != $$) { # forked, and I'm just a child.
        $self->{pid} = $$;
        if ($self->{lock} > 0) { # unlock! I'm not owner!
            flock $self->{fh}, LOCK_UN or die $!;
            $self->{lock} = 0;
        }
        $self->close();
        $self->open();
    }
}

sub DESTROY {
    my $self = shift;
    if ($self->{ppid} eq $$) { # cleanup method only run on original process.
        unlink $self->{filename};
    }
}

1;
