package App::Mobirc::Plugin::IRCCommand::TiarraLog;
use strict;
use warnings;
use App::Mobirc::Plugin;
use Encode;
use App::Mobirc::Util;

has sysmsg_prefix => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tiarra',
);

hook on_irc_notice => sub {
    my ($self, $global_context, $poe, $who, $channel, $msg) = @_;

    # Tiarra Log::Recent Parser
    if ($who && $who eq $self->sysmsg_prefix) {
        # header: %H:%M:%S
        # header: %H:%M
        # の場合を想定。後者は Log::Recent のデフォルトだったはず
        # kick とかに対応していない
        my $class;
        my $irc_incode = $poe->kernel->alias_resolve('irc_session')->get_heap->{config}->{incode};
        my $chann = encode($irc_incode , $channel->[0]);
        DEBUG "Parse Tiarra's Log::Recent message. $who NOTICE $channel->[0] :$msg";
        if ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) ! (\S+?) \((.*)\)|) {
            # ほんとは quit
            $class = "part";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) \+ (\S+?) \(([^\)]+)\) to (\S+)|) {
            $class = "join";
            $who   = $2;
            $msg   = "$2 join";
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) \- (\S+?) from (\S+)|) {
            $class = "part";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) Mode by (\S+?): (\S+) (.*)|) {
            $class = "mode";
            $who   = $2;
            $msg   = undef;
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) Topic of channel (\S+?) by (\S+): (.*)|) {
            $class = "topic";
            $who   = $3;
            $msg   = $4;
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) (\S+?) -> (\S+)|) {
            $class = "nick";
            $who   = $3;
            $msg   = $4;
            $chann = $chann;
        } elsif ($msg =~ qr|^([0-2]\d:[0-5]\d(?::[0-5]\d)?) [<>()=-]([^>]+?)[<>()=-] (.*)|) {
            # priv も notice もまとめて notice に
            # keyword 反応を再度しないため
            $class = "notice";
            $who   = $2;
            $msg   = $3;
            $chann = [$chann];
        }

        if ($class) {
            DEBUG "RE THROW Tiarra RECENT LOG->$class INCODE: $irc_incode.";
            $poe->kernel->call(
                $poe->session,
                "irc_$class",
                encode($irc_incode , $who),
                $chann,
                encode($irc_incode, $msg)
            );
            return true;
        }
    }

    return false;
};

1;
__END__

=head1 NAME

App::Mobirc::Plugin::IRCCommand::TiarraLog - Tiarra log blah-blah-blah

=head1 SYNOPSIS

  - module: App::Mobirc::Plugin::IRCCommand::TiarraLog
    config:
      sysmsg_prefix: tiarra

