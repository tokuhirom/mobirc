use strict;
use warnings;
use Test::More;
use Mobirc::Util;
eval "use Proc::Daemon; use File::Temp;";
if ($@) {
    plan skip_all => "Proc::Daemon, File::Temp is not installed.";
} else {
    plan tests => 1;
}

my $tmpfh = File::Temp->new(UNLINK => 0);
my $pid = fork();
if ($pid == 0) {
    # child
    daemonize($tmpfh->filename);
    exit(0);
} elsif ($pid > 0) {
    # parent
    wait;
    is slurp($tmpfh->filename), "$pid\n", 'pid file is exist';
    unlink $tmpfh->filename;
} else {
    die "fork error";
}

sub slurp {
    my $fname = shift;

    open my $fh, q{<}, $fname or die $!;
    my $dat = join '', <$fh>;
    close $fh;

    return $dat;
}

