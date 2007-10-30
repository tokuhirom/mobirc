package Mobirc::IRCClient;
use strict;
use warnings;

use POE;
use POE::Sugar::Args;
use POE::Component::IRC;

use Encode;
use Carp;

use Mobirc::Util;

sub init {
    my ($class, $config) = @_;

    # irc component
    my $irc = POE::Component::IRC->spawn(
        Alias    => 'mobirc_irc',
        Nick     => $config->{irc}->{nick},
        Username => $config->{irc}->{username},
        Ircname  => $config->{irc}->{desc},
        Server   => $config->{irc}->{server},
        Port     => $config->{irc}->{port},
        Password => $config->{irc}->{password}
    );

    POE::Session->create(
        heap => {
            seen_traffic   => false,
            disconnect_msg => true,
            channel_topic  => {},
            channel_name   => {},
            config         => $config,
            irc            => $irc,
        },
        inline_states => {
            _start           => \&on_irc_start,
            _default         => \&on_irc_default,

            irc_001          => \&on_irc_001,
            irc_join         => \&on_irc_join,
            irc_part         => \&on_irc_part,
            irc_public       => \&on_irc_public,
            irc_notice       => \&on_irc_notice,
            irc_topic        => \&on_irc_topic,
            irc_332          => \&on_irc_topicraw,
            irc_ctcp_action  => \&on_irc_ctcp_action,
            irc_kick         => \&on_irc_kick,
            irc_snotice      => \&on_irc_snotice,

            autoping         => \&do_autoping,
            connect          => \&do_connect,

            irc_disconnected => \&on_irc_reconnect,
            irc_error        => \&on_irc_reconnect,
            irc_socketerr    => \&on_irc_reconnect,
        }
    );
}

# -------------------------------------------------------------------------

sub on_irc_default {
    DEBUG "ignore unknown event: $_[ARG0]";
}

sub on_irc_start {
    my $poe = sweet_args;
    DEBUG "START";

    $poe->kernel->alias_set('irc_session');

    DEBUG "input charset is: " . $poe->heap->{config}->{irc}->{incode};

    $poe->heap->{irc}->yield( register => 'all' );
    $poe->heap->{irc}->yield( connect  => {} );
}

sub on_irc_001 {
    my $poe = sweet_args;

    DEBUG "CONNECTED";

    add_message( $poe,
        decode( 'utf8', '*server*' ),
        undef, decode('utf8', 'Connected to irc server!'), 'connect' );

    $poe->heap->{disconnect_msg} = true;
    $poe->heap->{channel_name} = {'*server*' => '*server*'};
    $poe->kernel->delay( autoping => $poe->heap->{config}->{ping_delay} );
}

sub on_irc_join {
    my $poe = sweet_args;

    DEBUG "JOIN";

    my ($who, $channel) = _get_args($poe);

    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of madoka)
    $channel =~ s/ .*//;

    my $canon_channel = canon_name($channel);

    $poe->heap->{channel_name}->{$canon_channel} = $channel;
    my $irc = $poe->heap->{irc};
    unless ( $who eq $irc->nick_name ) {
        add_message(
            $poe,
            $channel,
            undef,
            "$who joined",
            'join',
        );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_part {
    my $poe = sweet_args;

    my ($who, $channel, $msg) = _get_args($poe);

    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of POE::Filter::IRC)
    $channel =~ s/ .*//;

    my $canon_channel = canon_name($channel);

    my $irc = $poe->heap->{irc};
    if ( $who eq $irc->nick_name ) {
        delete $poe->heap->{channel_name}->{$canon_channel};
    }
    else {
        my $message = "$who leaves";
        if ($msg) {
            $message .= "($msg)";
        }

        add_message(
            $poe,
            $channel,
            undef,
            $message,
            'leave',
        );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_public {
    my $poe = sweet_args;

    DEBUG "IRC PUBLIC";

    my ($who, $channel, $msg) = _get_args($poe);

    $who =~ s/!.*//;

    $channel = $channel->[0];

    add_message(
        $poe, $channel,
        $who, $msg,
        'public',
    );

    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_notice {
    my $poe = sweet_args;

    my ($who, $channel, $msg) = _get_args($poe);

    DEBUG "IRC NOTICE";

    $who =~ s/!.*//;
    $channel = $channel->[0];

    add_message(
        $poe, $channel,
        $who, $msg,
        'notice',
    );
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_topic {
    my $poe = sweet_args;

    my ($who, $channel, $topic) = _get_args($poe);

    $who =~ s/!.*//;

    DEBUG "SET TOPIC";

    add_message( $poe,
        $channel,
        undef, "$who set topic: $topic",
        'topic',
        );

    $poe->heap->{channel_topic}->{canon_name($channel)} = $topic;

    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_topicraw {
    my $poe = sweet_args;

    DEBUG "SET TOPIC RAW";

    my ($w, $raw) = _get_args($poe);

    my ( $channel, $topic ) = split( / :/, $raw, 2 );

    $poe->heap->{channel_topic}->{ canon_name($channel) } = $topic;
    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_ctcp_action {
    my $poe = sweet_args;

    my ($who, $channel, $msg) = _get_args($poe);

    $who =~ s/!.*//;
    $channel = $channel->[0];
    $msg = sprintf( '* %s %s', $who, $msg );

    add_message( $poe, $channel, '', $msg, 'ctcp_action', );

    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_kick {
    my $poe = sweet_args;

    DEBUG "DNBKICK";

    my ($kicker, $channel, $kickee, $msg) = _get_args($poe);
    $msg ||= 'Flooder';

    $kicker =~ s/!.*//;

    add_message(
        $poe, $channel, '', "$kicker has kicked $kickee($msg)", 'kick'
    );
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub do_connect {
    my $poe = sweet_args;

    $poe->heap->{irc}->yield( connect => {} );
}

sub do_autoping {
    my $poe = sweet_args;

    $poe->kernel->post( mobirc_irc => time ) unless $poe->heap->{seen_traffic};
    $poe->heap->{seen_traffic} = false;
    $poe->kernel->delay( autoping => $poe->heap->{config}->{ping_delay} );
}

sub on_irc_snotice {
    my $poe = sweet_args;

    my ($message, ) = _get_args($poe);

    DEBUG "getting snotice : $message";

    add_message(
        $poe,
        decode( 'utf8', '*server*' ),
        undef,
        $message,
        'snotice',
    );
}

sub on_irc_reconnect {
    my $poe = sweet_args;

    if ( $poe->heap->{disconnect_msg} ) {
        add_message(
            $poe,
            decode( 'utf8', '*server*' ),
            undef,
            decode( 'utf8', 'Disconnected from irc server, trying to reconnect...'),
            'reconnect',
        );
    }
    $poe->heap->{disconnect_msg} = false;
    $poe->kernel->delay( connect => $poe->heap->{config}->{reconnect_delay} );
}

# FIXME: I want more cool implement
sub _get_args {
    my $poe = shift;

    my @ret;
    for my $elem (@{$poe->args}) {
        if ( ref $elem && ref $elem eq 'ARRAY') {
            push @ret, [map { decode($poe->heap->{config}->{irc}->{incode}, $_) } @$elem];
        } else {
            push @ret, decode($poe->heap->{config}->{irc}->{incode}, $elem);
        }
    }
    return @ret;
}

1;
