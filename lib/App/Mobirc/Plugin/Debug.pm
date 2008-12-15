package App::Mobirc::Plugin::Debug;
use strict;
use App::Mobirc::Plugin;
use GTop;
use utf8;

my $gtop = GTop->new;
warn "LOAD";

hook process_command => sub {
    my ( $self, $global_context, $command, $channel ) = @_;
    if ($command =~ /!dan/) {
        printf "Process size : %d\n", $gtop->proc_mem($$)->size;
    }
    return 0;
};

1;
