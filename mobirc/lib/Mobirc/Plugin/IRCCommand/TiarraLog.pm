package Mobirc::Plugin::IRCCommand::TiarraLog;
use strict;
use warnings;
use Encode;
use Mobirc::Util;

sub register {
    my ($class, $global_context) = @_;

    $global_context->register_hook(
        'on_irc_notice' => \&_process,
    );
}

sub _process {
    my ($poe, $who, $channel, $msg) = @_;

    DEBUG "parse tiara's Log::Recent log";

    # Tiarra Log::Recent Parser
    if ($who && $who eq "tiarra") {
        # header: %H:%M:%S
        # header: %H:%M
        # の場合を想定。後者は Log::Recent のデフォルトだったはず
        # kick とかに対応していない
        my $class;
        my $irc_incode = $poe->kernel->alias_resolve('irc_session')->get_heap->{config}->{incode};
        DEBUG "IRC INCODE IS $irc_incode";
        my $chann  = encode($irc_incode , $channel->[0]);
        if ($msg =~ qr|^(\d\d:\d\d(?::\d\d)?) ! ([^\s]+?) \((.*)\)|) {
            # ほんとは quit
            $class = "part";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) \+ ([^\s]+?) \(([^\)]+)\) to ([^\s]+)|) {
            $class = "join";
            $who   = $2;
            $msg   = decode("utf8", "$2 join");
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) \- ([^\s]+?) from ([^\s]+)|) {
            $class = "part";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) Mode by ([^\s]+?): ([^\s]+) (.*)|) {
            $class = "mode";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) Topic of channel ([^\s]+?) by ([^\s]+): (.*)|) {
            $class = "topic";
            $who   = $3;
            $msg   = $4;
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) ([^\s]+?) -> ([^\s]+)|) {
            $class = "nick";
            $who   = $3;
            $msg   = $4;
            $chann = $chann;
        } elsif ($msg =~ qr|^(\d\d:\d\d(?::\d\d)) [<>()=-]([^>]+?)[<>()=-] (.*)|) {
            # priv も notice もまとめて notice に
            # keyword 反応を再度しないため
            $class = "notice";
            $who   = $2;
            $msg   = $3;
            $chann = [$chann];
        }

        if ($class) {
            DEBUG "RE THROW Tiarra RECENT LOG->$class";
            $poe->kernel->call(
                $poe->session,
                "irc_$class",
                $who,
                $chann,
                encode($irc_incode, $msg)
            );
            return true;
        }
    }

    return false;
}

1;
