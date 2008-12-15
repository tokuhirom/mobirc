package App::Mobirc::Plugin::Debug;
use strict;
use App::Mobirc::Plugin;
use utf8;

hook process_command => sub {
    my ( $self, $global_context, $command, $channel ) = @_;
    if (my ($command, ) = ( $command =~ /^!(\S+)/ )) {
        my $meth = "do_$command";
        __PACKAGE__->$meth;
    }
    return 0;
};

sub do_memory {
    require GTop;
    my $gtop = GTop->new;
    printf "Process size : %d\n", $gtop->proc_mem($$)->size;
}

sub do_dumpinc {
    require Data::Dumper;
    warn Data::Dumper::Dumper(\%INC);
}

sub do_reload {
    require Module::Reload;
    Module::Reload->check;
}

1;
