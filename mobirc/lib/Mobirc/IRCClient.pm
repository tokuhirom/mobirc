package Mobirc::IRCClient;
use strict;
use warnings;
use boolean ':all';

use POE;
use POE::Sugar::Args;
use POE::Component::IRC;

use Encode;
use Carp;

use Mobirc::Util;

sub init {
    my ($class, $config) = @_;

    # irc component
    POE::Component::IRC->spawn(
        Alias    => 'keitairc_irc',
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
            channel_topic => {},
            channel_mtime => {},
            config => $config,
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

    my $irc = $poe->kernel->alias_resolve('keitairc_irc');
    $poe->kernel->post( $irc, register => 'all' );
    $poe->kernel->post( $irc, connect  => {} );
}

sub on_irc_001 {
    my $poe = sweet_args;

    DEBUG "CONNECTED";

    for my $channel ( sort keys %{ $poe->heap->{channel_name} } ) {
        &add_message( $poe, decode( $poe->heap->{config}->{irc}->{incode}, $channel), undef, 'Connected to irc server!' );
    }
    $poe->heap->{disconnect_msg} = true;
    $poe->heap->{channel_name} = {};
    $poe->kernel->delay( autoping => $poe->heap->{config}->{ping_delay} );
}

sub on_irc_join {
    my $poe = sweet_args;

    my $who = $poe->args->[0];
    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of madoka)
    my $channel = $poe->args->[1];
    $channel =~ s/ .*//;
    my $canon_channel = canon_name($channel);

    $poe->heap->{channel_name}->{$canon_channel} = $channel;
    unless ( $who eq $poe->heap->{config}->{irc}->{nick} ) {
        add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), undef, decode($poe->heap->{config}->{irc}->{incode}, "$who joined") );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_part {
    my $poe = sweet_args;

    my $who = $poe->args->[0];
    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of POE::Filter::IRC)
    my $channel = $poe->args->[1];
    $channel =~ s/ .*//;
    my $canon_channel = canon_name($channel);

    if ( $who eq $poe->heap->{config}->{irc}->{nick} ) {
        delete $poe->heap->{channel_name}->{$canon_channel};
    }
    else {
        add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), undef, decode($poe->heap->{config}->{irc}->{incode}, "$who leaves") );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_public {
    my $poe = sweet_args;

    DEBUG "IRC PUBLIC";
    my $who = $poe->args->[0];
    $who =~ s/!.*//;
    my $channel = $poe->args->[1];
    $channel = $channel->[0];

    my $msg = $poe->args->[2];

    add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), $who, decode($poe->heap->{config}->{irc}->{incode}, $msg) );

    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_notice {
    my $poe = sweet_args;

    my $who = $poe->args->[0];
    my $channel = $poe->args->[1];
    my $msg = $poe->args->[2];

    DEBUG "IRC NOTICE";

    $who =~ s/!.*//;
    $channel = $channel->[0];

    add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), $who, decode($poe->heap->{config}->{irc}->{incode}, $msg) );
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_topic {
    my $poe = sweet_args;

    my $who = $poe->args->[0];
    my $channel = $poe->args->[1];
    my $topic = $poe->args->[2];

    $who =~ s/!.*//;

    DEBUG "SET TOPIC";

    $topic = decode($poe->heap->{config}->{irc}->{incode}, $topic);
    add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), undef, "$who set topic: $topic" );

    $poe->heap->{channel_topic}->{canon_name($channel)} = $topic;

    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_topicraw {
    my $poe = sweet_args;

    my $raw = $poe->args->[1];
    my ( $channel, $topic ) = split( / :/, $raw, 2 );

    $poe->heap->{channel_topic}->{ canon_name($channel) } = $topic;
    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_ctcp_action {
    my $poe = sweet_args;

    my $who = $poe->args->[0];
    my $channel = $poe->args->[1];
    my $msg = $poe->args->[2];

    $who =~ s/!.*//;
    $channel = $channel->[0];
    $msg = sprintf( '* %s %s', $who, decode( $poe->heap->{config}->{irc}->{incode}, $msg) );
    add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), '', $msg );
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub do_connect {
    my $poe = sweet_args;

    $poe->kernel->post( keitairc_irc => connect => {} );
}

sub do_autoping {
    my $poe = sweet_args;

    $poe->kernel->post( keitairc_irc => time ) unless $poe->heap->{seen_traffic};
    $poe->heap->{seen_traffic} = false;
    $poe->kernel->delay( autoping => $poe->heap->{config}->{ping_delay} );
}

sub on_irc_reconnect {
    my $poe = sweet_args;

    if ( $poe->heap->{disconnect_msg} ) {
        for my $channel ( sort keys %{ $poe->heap->{channel_name} } ) {
            add_message( $poe, decode($poe->heap->{config}->{irc}->{incode}, $channel), undef,
                'Disconnected from irc server, trying to reconnect...' );
        }
    }
    $poe->heap->{disconnect_msg} = false;
    $poe->kernel->delay( connect => $poe->heap->{config}->{reconnect_delay} );
}

1;
