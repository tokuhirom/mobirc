package App::Mobirc::Plugin::Component::IRCClient;
use strict;
use App::Mobirc::Plugin;

use AnyEvent;
use AnyEvent::IRC;
use AnyEvent::IRC::Client;
use Data::Recursive::Encode;

use Encode;
use Carp;

use App::Mobirc::Model::Message;
use App::Mobirc::Util;

has timeout => (
    is      => 'ro',
    isa     => 'Int',
    default => 10,
);

has conn => (
    is  => 'rw',
    isa => 'AnyEvent::IRC::Client',
);

has ping_delay => (
    is      => 'ro',
    isa     => 'Int',
    default => 30,
);

has reconnect_delay => (
    is      => 'ro',
    isa     => 'Int',
    default => 10,
);

has incode => (
    is      => 'ro',
    isa     => 'Str',
    default => 'UTF-8',
);

has nick => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has username => (
    is      => 'ro',
    isa     => 'Str',
    default => 'mobirc user',
);

has desc => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has server => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has port => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has password => (
    is  => 'ro',
    isa => 'Str',
);

hook process_command => sub {
    my ( $self, $global_context, $command, $channel ) = @_;

    my $irc_incode = $self->incode;
    if ( $command && $channel->name =~ /^[#*%]/ ) {
        if ( $command =~ m{^/me(.*)} ) {
            DEBUG "CTCP ACTION";
            my $body = $1;

            $self->conn->send_srv(
                PRIVMSG => $channel->name() => encode_ctcp(['ACTION', $body])
            );

            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => $self->current_nick(),
                    body  => $body,
                    class => 'ctcp_action',
                )
            );
        }
        elsif ( $command =~ m{^/} ) {
            DEBUG "SENDING COMMAND";
            $command =~ s!^/!!g;

            my @args =
              map { encode( $irc_incode, $_ ) } split /\s+/,
              $command;

            $self->conn->send_srv(@_);
        }
        else {
            DEBUG "NORMAL PRIVMSG";

            $self->conn->send_srv(
                'PRIVMSG',
                encode( $irc_incode, $channel->name ),
                encode( $irc_incode, $command )
            );

            DEBUG "Sending command $command";

            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => $self->current_nick(),
                    body  => $command,
                    class => 'public',
                )
            );
        }
        return true;
    }
    return false;
};

hook 'run_component' => sub {
    my ( $self, $global_context ) = @_;

    DEBUG "initialize ircclient";

    my $irc = AnyEvent::IRC::Client->new();
    $irc->connect(
        $self->server,
        $self->port,
        {
            nick => $self->nick,
            real => $self->desc,
            password => $self->password,
            timeout => $self->timeout,
        }
    );
    my $disconnect_msg = 1;
    my %cb             = (
        irc_001 => sub {
            DEBUG "CONNECTED";
            DEBUG "input charset is: " . $self->incode();

            my $channel = $global_context->get_channel('*server*');
            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => undef,
                    body  => 'Connected to irc server!',
                    class => 'connect',
                )
            );

            $disconnect_msg = true;
        },
        'registered' => sub {
            DEBUG 'registered event';
            $irc->enable_ping(
                $self->{ping_delay},
                sub {
                    print "disconnected connection\n";
                }
            );
        },
        'join' => sub {
            my ( $who, $channel_name, $is_myself ) = @_;
            DEBUG "JOIN($who, $channel_name, $is_myself)";
            $who =~ s/!.*//;

            # chop off after the gap (bug workaround of madoka)
            $channel_name =~ s/ .*//;

            # create channel
            my $channel = $global_context->get_channel($channel_name);

            unless ($is_myself) {
                $channel->add_message(
                    App::Mobirc::Model::Message->new(
                        who   => undef,
                        body  => $who . " joined",
                        class => 'join',
                    )
                );
            }
            $disconnect_msg = true;
        },
#       'part' => sub {
#           my ( $who, $channel_name, $is_myself, $msg ) = @_;
#           DEBUG("PART($who, $channel_name, $is_myself, $msg)");

#           $who =~ s/!.*//;

#           # chop off after the gap (bug workaround of POE::Filter::IRC)
#           $channel_name =~ s/ .*//;

#           if ($is_myself) {
#               $global_context->delete_channel($channel_name);
#           }
#           else {
#               my $message = "$who leaves";
#               if ($msg) {
#                   $message .= "($msg)";
#               }

#               my $channel = $global_context->get_channel($channel_name);
#               $channel->add_message(
#                   App::Mobirc::Model::Message->new(
#                       who   => undef,
#                       body  => $message,
#                       class => 'leave',
#                   )
#               );
#           }
#           $disconnect_msg = true;
#       },
        'kick' => sub {
            my ( $irc, $kickee, $channel_name, $is_myself, $msg ) = @_;
            DEBUG "KICK($kickee, $channel_name, $is_myself, $msg)----------------------";
            my $kicker = 'anyone'; # AnyEvent::IRC::Client doesn't supports kicker!
            $msg ||= 'Flooder';

            $kicker =~ s/!.*//;

            $global_context->get_channel($channel_name)->add_message(
                App::Mobirc::Model::Message->new(
                    who   => undef,
                    body  => "$kicker has kicked $kickee($msg)",
                    class => 'kick',
                )
            );

            $disconnect_msg = true;
        },
        'publicmsg' => sub {
            my ( $irc, $targ, $raw ) = @_;
            my $who          = $raw->{prefix} || '*';
            my $channel_name = $raw->{params}->[0];
            my $msg          = $raw->{params}->[1];
            my $class        = $raw->{command};
            DEBUG "IRC_PRIVMSG($who, $channel_name, $msg)";

            $who =~ s/!.*//;

            $channel_name = normalize_channel_name($channel_name); # TODO: move to get_channel.

            my $channel = $global_context->get_channel($channel_name);
            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => $who,
                    body  => $msg,
                    class => lc($class) eq 'privmsg' ? 'public' : 'notice',
                )
            );

            if ( $who eq $irc->nick ) {
                DEBUG "CLEAR UNREAD, because I said.";
                $channel->clear_unread;
            }

            $disconnect_msg = true;
        },
        channel_topic => sub {
            my ( $irc, $channel_name, $topic, $who ) = @_;
            DEBUG "CHANNEL_TOPIC($channel_name, $topic, $who)";

            $who =~ s/!.*//;

            my $channel = $global_context->get_channel($channel_name);
            $channel->topic($topic);
            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => undef,
                    body  => "$who set topic: $topic",
                    class => 'topic',
                )
            );

            $disconnect_msg = true;
        },
        # TODO: CTCP ACTION SUPPORT
        ctcp_action => sub {
            my ( $irc, $who, $channel_name, $msg ) = @_;
            DEBUG("CTCP_ACTION($who, $channel_name, $msg)");

            $who =~ s/!.*//;

            my $channel = $global_context->get_channel($channel_name);
            my $body = sprintf( '* %s %s', $who, $msg );
            $channel->add_message(
                App::Mobirc::Model::Message->new(
                    who   => undef,
                    body  => $body,
                    class => 'ctcp_action',
                )
            );

            $disconnect_msg = true;
        },
        # TODO : support snotice
#       irc_snotice => sub {
#           DEBUG "getting snotice : $message";

#           my $channel = $global_context->get_channel('*server*');
#           $channel->add_message(
#               App::Mobirc::Model::Message->new(
#                   who   => undef,
#                   body  => $message,
#                   class => 'snotice',
#               )
#           );
#       },
        # handle error.
        'error' => sub {
            my ($self, $command, $message) = @_;
            print STDERR "ERROR: $command($message)";
        },
        debug_recv => sub {
            my ($irc, $raw) = @_;
            # use Data::Dumper;
            DEBUG "message: $raw->{command}";
        },
#       channel_add => sub {
#           my ($msg, $channel_name, @nicks) = @_;
#           DEBUG "CHANNEL_ADDR($msg, $channel_name)";
#           $global_context->get_channel($channel_name);
#       },
#       channel_remove => sub {
#           DEBUG 'channel_remove event';
#       },
    );

    # decode args, automatically.
    while ( my ( $key, $code ) = each %cb ) {
        $cb{$key} = sub {
            return $code->(@{Data::Recursive::Encode->decode($self->incode, \@_)});
        };
    }
    $cb{privatemsg} = $cb{publicmsg};
    $irc->reg_cb(%cb);
    $self->conn($irc);

    $global_context->add_channel(
        App::Mobirc::Model::Channel->new( name => '*server*' )
    );

    $global_context->irc_component($self);
};

# decoded current nick
sub current_nick {
    my $self = shift;
    $self->_decode( $self->conn->nick() );
}

sub _decode {
    my ( $self, $src ) = @_;
    return decode( $self->incode, $src );
}

1;
