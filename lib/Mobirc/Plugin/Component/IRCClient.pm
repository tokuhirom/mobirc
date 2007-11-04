package Mobirc::Plugin::Component::IRCClient;
use strict;
use warnings;

use POE;
use POE::Sugar::Args;
use POE::Component::IRC;

use Encode;
use Carp;

use Mobirc::Message;
use Mobirc::Util;

sub register {
    my ($class, $global_context, $conf) = @_;

    DEBUG "register ircclient component";
    $global_context->register_hook(
        'run_component' => sub { _init($conf, shift) },
    );
    $global_context->register_hook(
        'process_command' => sub { my ($global_context, $command, $channel) = @_;  _process_command($conf, $global_context, $command, $channel) },
    );
}

sub _process_command {
    my ($conf, $global_context, $command, $channel) = @_;

    my $irc_incode = $conf->{incode};
    if ($command && $channel->name =~ /^[#*%]/) {
        if ($command =~ m{^/}) {
            DEBUG "SENDING COMMAND";
            $command =~ s!^/!!g;

            my @args =
              map { encode( $irc_incode, $_ ) } split /\s+/,
              $command;

            $poe_kernel->post('mobirc_irc', @args);
        } else {
            DEBUG "NORMAL PRIVMSG";

            $poe_kernel->post( 'mobirc_irc',
                privmsg => encode( $irc_incode, $channel->name ) =>
                encode( $irc_incode, $command ) );

            DEBUG "Sending command $command";
            # FIXME: httpd 関係ない件
            if ($global_context->config->{httpd}->{echo} eq true) {
                $channel->add_message(
                    Mobirc::Message->new(
                        who => decode(
                            $irc_incode,
                            $conf->{irc_nick}
                        ),
                        body  => $command,
                        class => 'public',
                    )
                );
            }
        }
        return true;
    }
    return false;
}

sub _init {
    my ($config, $global_context) = @_;

    DEBUG "initialize ircclient";
    # irc component
    my $irc = POE::Component::IRC->spawn(
        Alias    => 'mobirc_irc',
        Nick     => $config->{nick},
        Username => $config->{username},
        Ircname  => $config->{desc},
        Server   => $config->{server},
        Port     => $config->{port},
        Password => $config->{password}
    );

    POE::Session->create(
        heap => {
            seen_traffic   => false,
            disconnect_msg => true,
            config         => $config,
            irc            => $irc,
            global_context => $global_context,
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

    $global_context->add_channel(
        Mobirc::Channel->new($global_context, U('*server*'))
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

    DEBUG "input charset is: " . $poe->heap->{config}->{incode};

    $poe->heap->{irc}->yield( register => 'all' );
    $poe->heap->{irc}->yield( connect  => {} );
}

sub on_irc_001 {
    my $poe = sweet_args;

    DEBUG "CONNECTED";

    my $channel = $poe->heap->{global_context}->get_channel(decode( 'utf8', '*server*' ));
    $channel->add_message(
        Mobirc::Message->new(
            who   => undef,
            body  => decode('utf8', 'Connected to irc server!'),
            class => 'connect',
        )
    );

    $poe->heap->{disconnect_msg} = true;
    $poe->kernel->delay( autoping => $poe->heap->{config}->{ping_delay} );
}

sub on_irc_join {
    my $poe = sweet_args;

    DEBUG "JOIN";

    my ($who, $channel_name) = _get_args($poe);

    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of madoka)
    $channel_name =~ s/ .*//;
    $channel_name = normalize_channel_name($channel_name);

    # create channel
    my $channel = $poe->heap->{global_context}->get_channel($channel_name);
    unless ($channel) {
        $channel = Mobirc::Channel->new(
            $poe->heap->{global_context},
            $channel_name,
        );
        $poe->heap->{global_context}->add_channel( $channel );
    }

    my $irc = $poe->heap->{irc};
    unless ( $who eq $irc->nick_name ) {
        $channel->add_message(
            Mobirc::Message->new(
                who   => undef,
                body  => $who . U(" joined"),
                class => 'join',
            )
        );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_part {
    my $poe = sweet_args;

    my ($who, $channel_name, $msg) = _get_args($poe);

    $who =~ s/!.*//;

    # chop off after the gap (bug workaround of POE::Filter::IRC)
    $channel_name =~ s/ .*//;
    $channel_name = normalize_channel_name($channel_name);

    my $irc = $poe->heap->{irc};
    if ( $who eq $irc->nick_name ) {
        delete $poe->heap->{global_context}->channels->{$channel_name};
    }
    else {
        my $message = "$who leaves";
        if ($msg) {
            $message .= "($msg)";
        }

        my $channel = $poe->heap->{global_context}->get_channel($channel_name);
        $channel->add_message(
            Mobirc::Message->new(
                who   => undef,
                body  => $message,
                class => 'leave',
            )
        );
    }
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_public {
    my $poe = sweet_args;

    DEBUG "IRC PUBLIC";

    my ($who, $channel_name, $msg) = _get_args($poe);

    $who =~ s/!.*//;

    $channel_name = $channel_name->[0];
    $channel_name = normalize_channel_name($channel_name);

    my $channel = $poe->heap->{global_context}->get_channel($channel_name);
    $channel->add_message(
        Mobirc::Message->new(
            who   => $who,
            body  => $msg,
            class => 'public',
        )
    );

    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_notice {
    my $poe = sweet_args;

    my ($who, $channel_name, $msg) = _get_args($poe);

    DEBUG "IRC NOTICE";

    for my $code (@{ $poe->heap->{global_context}->get_hook_codes('on_irc_notice') }) {
        my $finished = $code->($poe, $who, $channel_name, $msg);
        return if $finished;
    }

    $who =~ s/!.*//;
    $channel_name = $channel_name->[0];
    $channel_name = normalize_channel_name($channel_name);

    my $channel = $poe->heap->{global_context}->get_channel($channel_name);
    $channel->add_message(
        Mobirc::Message->new(
            who   => $who,
            body  => $msg,
            class => 'notice',
        )
    );
    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_topic {
    my $poe = sweet_args;

    my ($who, $channel_name, $topic) = _get_args($poe);

    $who =~ s/!.*//;

    DEBUG "SET TOPIC";
    $channel_name = normalize_channel_name($channel_name);

    my $channel = $poe->heap->{global_context}->get_channel($channel_name);
    $channel->topic($topic);
    $channel->add_message(
        Mobirc::Message->new(
            who   => undef,
            body  => "$who set topic: $topic",
            class => 'topic',
        )
    );

    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_topicraw {
    my $poe = sweet_args;

    my ($x, $y, $dat) = _get_args($poe);

    my ( $channel, $topic ) = @{$dat};

    DEBUG "SET TOPIC RAW: $channel => $topic";

    $poe->heap->{global_context}->get_channel(normalize_channel_name($channel))->topic($topic);
    $poe->heap->{seen_traffic}                  = true;
    $poe->heap->{disconnect_msg}                = true;
}

sub on_irc_ctcp_action {
    my $poe = sweet_args;

    my ($who, $channel_name, $msg) = _get_args($poe);

    $who =~ s/!.*//;
    $channel_name = $channel_name->[0];

    my $channel = $poe->heap->{global_context}->get_channel($channel_name);
    my $body = sprintf(decode('utf8', "* %s %s"), $who, $msg);
    $channel->add_message(
        Mobirc::Message->new(
            who   => undef,
            body  => $body,
            class => 'ctcp_action',
        )
    );

    $poe->heap->{seen_traffic}   = true;
    $poe->heap->{disconnect_msg} = true;
}

sub on_irc_kick {
    my $poe = sweet_args;

    DEBUG "DNBKICK";

    my ($kicker, $channel_name, $kickee, $msg) = _get_args($poe);
    $msg ||= 'Flooder';

    $kicker =~ s/!.*//;

    $poe->heap->{global_context}->get_channel($channel_name)->add_message(
        Mobirc::Message->new(
            who   => undef,
            body  => "$kicker has kicked $kickee($msg)",
            class => 'kick',
        )
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

    my $channel = $poe->heap->{global_context}->get_channel(U('*server*' ));
    $channel->add_message(
        Mobirc::Message->new(
            who   => undef,
            body  => $message,
            class => 'snotice',
        )
    );
}

sub on_irc_reconnect {
    my $poe = sweet_args;

    DEBUG "!RECONNECT! " . $poe->heap->{disconnect_msg};
    if ( $poe->heap->{disconnect_msg} ) {
        my $channel = $poe->heap->{global_context}->get_channel(decode( 'utf8', '*server*' ));
        $channel->add_message(
            Mobirc::Message->new(
                who   => undef,
                body  => decode( 'utf8', 'Disconnected from irc server, trying to reconnect...'),
                class => 'reconnect',
            )
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
            push @ret, [map { decode($poe->heap->{config}->{incode}, $_) } @$elem];
        } else {
            push @ret, decode($poe->heap->{config}->{incode}, $elem);
        }
    }
    return @ret;
}

1;
