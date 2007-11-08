package Mobirc::Plugin::Component::XMPP;
use strict;
use warnings;
use POE;
use POE::Sugar::Args;
use POE::Component::Jabber;
use POE::Component::Jabber::Error;          #include error constants
use POE::Component::Jabber::Status;         #include status constants
use POE::Component::Jabber::ProtocolFactory ();#include connection type constants
use POE::Filter::XML::Node;                 #include to build nodes
use POE::Filter::XML::NS qw/ :JABBER :IQ /; #include namespace constants
use POE::Filter::XML::Utils;                #include some general utilites
use POE::Component::Jabber::XMPP;
use Carp;
use Mobirc::Channel;
use Mobirc::Util;

sub config_schema {
    {
        type    => 'map',
        mapping => {
            jid => {
                type     => 'str',
                required => 1,
            },
            password => {
                type     => 'str',
                required => 1,
            },
            hostname        => { type => 'str', },
            alias           => { type => 'str', },
            connection_type => { type => 'int', },
            port            => { type => 'int', },
        }
    }
}

our $PLUGIN_COUNT = 0;
sub register {
    my ($class, $global_context, $conf) = @_;

    DEBUG "register xmpp client component";

    for my $key (qw/jid password/) {
        die "missing configuration key: $key" unless $conf->{$key};
    }

    $PLUGIN_COUNT++;
    $global_context->register_hook(
        'run_component' => sub { _init($conf, $PLUGIN_COUNT, shift) },
    );
    $global_context->register_hook(
        'process_command' => sub {
            my ( $global_context, $command, $channel ) = @_;
            _process_command( $conf, $global_context, $command, $channel );
        },
    );

    $conf->{alias} ||= "XMPP$PLUGIN_COUNT";
    $conf->{parent_alias} ||= "ParentXMPP$PLUGIN_COUNT";
    $conf->{resource} ||= 'mobirc';
    $conf->{connection_type} ||= POE::Component::Jabber::ProtocolFactory::XMPP;
}

sub _process_command {
    my ($conf, $global_context, $command, $channel) = @_;

    DEBUG "PROCESS COMMAND AT XMPP";
    if (my $to_jid = _get_to_jid($channel->name)) {
        DEBUG "TO JID IS: $to_jid";
        my $from_jid = $poe_kernel->alias_resolve($conf->{parent_alias})->get_heap->{client}->jid;
        DEBUG "from jid is: $from_jid";
        my $node = POE::Filter::XML::Node->new(
            'message',
            [
                from => $from_jid,
                to   => $to_jid,
                type => 'chat',
            ]
        );
        $node->insert_tag('body')->data($command);
        DEBUG "sending " . $node->to_str;
        $poe_kernel->call( $conf->{alias}, 'output_handler', $node );

        return true;
    } else {
        return false;
    }
}

sub _get_to_jid {
    my $channel_name = shift;

    if ($channel_name =~ /^xmpp\[(.+)\]$/) {
        return $1;
    } else {
        return;
    }
}

sub _init {
    my ($conf, $plugin_count, $global_context) = @_;
    croak "global context missing" unless $global_context;

    POE::Session->create(
        heap => {
            conf => $conf,
            global_context => $global_context,
        },
        inline_states => {
            _start => sub {
                my $poe = sweet_args;
                $poe->kernel->alias_set($conf->{parent_alias});
                unless ($conf->{jid} =~ /@/) {
                    die "invalid jid: $conf->{jid}";
                }
                my ($username, $componentname) = split /@/, $conf->{jid};
                DEBUG "username: $username, componentname: $componentname, hostname: $conf->{hostname}";
                my $client = POE::Component::Jabber->new(
                    IP             => $conf->{hostname} || $componentname,
                    PORT           => $conf->{port} || 5222,
                    HOSTNAME       => $componentname,
                    USERNAME       => $username,
                    PASSWORD       => $conf->{password},
                    ALIAS          => $conf->{alias},
                    RESOURCE       => $conf->{resource},
                    CONNECTIONTYPE => $conf->{connection_type},
                    STATES         => {
                        InputEvent  => 'input_event',
                        ErrorEvent  => 'error_event',
                        StatusEvent => 'status_event',
                    }
                );
                $poe->heap->{client} = $client;
                $poe->kernel->post( $conf->{alias}, 'connect' );
            },
            input_event  => \&_input_event,
            error_event  => \&_error_event,
            status_event => \&_status_event,
        }
    );
}

sub _input_event {
    my $poe = sweet_args;
    my $node = $poe->args->[0];
    DEBUG "INPUT EVENT!";
    DEBUG $node->to_str;

    if ($node->name eq 'message') {
        DEBUG "message stanza";
        unless ($node->attr('type') eq 'chat') {
            DEBUG "ignore error message stanza.";
            return;
        }

        my $body_elem = $node->get_children_hash->{body};
        my $conf = $poe->heap->{conf};
        my $channel = $poe->heap->{global_context}->get_channel( sprintf(U("xmpp[%s]"), $node->attr('from')) );
        $channel->add_message(
            Mobirc::Message->new(
                who   => undef,
                body  => $body_elem->data,
                class => 'public',
            )
        );
    }
}

sub _status_event {
    my $poe = sweet_args;
    my $status_code = $poe->args->[0];

    if ($status_code == +PCJ_INIT_FINISHED) {
        my $node = POE::Filter::XML::Node->new( 'presence', [] );
        $poe->kernel->call( $poe->heap->{conf}->{alias}, 'output_handler', $node );
        return;
    }

  # # follow code is only for debug.
  # for my $code (@POE::Component::Jabber::Status::EXPORT) {
  #     next if $code eq 'PCJ_RECONNECT'; # this is PoCo::Jabber's bug. see RT#30467

  #     no strict 'refs'; ## no critic.
  #     if (&{"POE::Component::Jabber::Status::$code"} == $status_code) {
  #         DEBUG "STATUS EVENT: $code";
  #         return;
  #     }
  # }
    DEBUG "STATUS EVENT: $status_code";
}

sub _error_event {
    my $poe = sweet_args;
    use Data::Dumper; warn Dumper($poe->args);
    DEBUG "ERROR EVENT";
}

1;

__END__

=head1 NAME

Mobirc::Plugin::Component::XMPP - xmpp component for mobirc.

=head1 SYNOPSIS

  - module: Mobirc::Plugin::Component::XMPP
    config:
      jid: example@gmail.com
      password: sexy
      hostname: talk.google.com
      port: 5222

