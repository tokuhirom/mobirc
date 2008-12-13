use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib File::Spec->catfile($FindBin::RealBin, 'lib');

use Irssi;

use Glib;
use POE::Sugar::Args;
use POE qw/Session::Irssi Loop::Glib/;

use Encode;
use App::Mobirc;
use App::Mobirc::Util;
use Module::Reload;
use YAML::Syck;

our %IRSSI = ( name => 'mobirc' );

Irssi::settings_add_str('mobirc', 'mobirc_config_path', '');
Irssi::settings_add_bool('mobirc', 'mobirc_auto_start', 0);

POE::Session::Irssi->create(
    inline_states => {
        map { ( $_ => __PACKAGE__->can("poe_$_") ) }
            qw/_start load initialize_mobirc unload/
    },

    irssi_commands => {
        mobirc => sub {
            my $poe = sweet_args;
            my ($data, $server, $witem) = @{ $poe->args->[1] };

            if (($data || '') =~ /start/) {
                if ($poe->kernel->alias_resolve('mobirc_httpd')) {
                    Irssi::print('mobirc is already started!');
                    return;
                }
                $poe->kernel->yield('load');
            }
            elsif (($data || '') =~ /stop/) {
                $poe->kernel->yield('unload');
            }
        },
    },

    irssi_signals => {
        map( { ( "message $_" => bind_signal("irssi_$_") ) }
            qw/public private own_public own_private join part quit kick nick own_nick invite topic/
        ),
        map( { ( "message irc $_" => bind_signal("irssi_irc_$_") ) }
            qw/op_public own_wall own_action action own_notice notice own_ctcp ctcp/
        ),
        'server event' => bind_signal('irssi_irc_snotice'),
        'print text' => bind_signal('irssi_print_text'),
        'command script unload' => \&script_unload,
    },
);

sub nick_name {
    my $server = Irssi::active_server() or return '';
    $server->{nick};
}

sub bind_signal {
    my $sub = __PACKAGE__->can(shift) or return;

    return sub {
        return unless $_[KERNEL]->alias_resolve('mobirc_httpd');
        $sub->(@_);
    };
}

sub poe__start {
    my $poe = sweet_args;

    if (Irssi::settings_get_bool('mobirc_auto_start')) {
        $poe->kernel->yield('load');
    }
}

sub poe_load {
    my $poe = sweet_args;
                    Irssi::print('mobirc is already started!');
    Module::Reload->check;

    my $mobirc = $poe->kernel->call( $poe->session, 'initialize_mobirc')
        or return;

    # dummy irc session to handle post message from httpd
    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->alias_set('irc_session');
            },
        },
        heap => {
            irc => __PACKAGE__,
            config => { incode => 'utf-8' },
        },
    );

    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->alias_set('mobirc_irc');
            },

        },
    );

    $mobirc->register_hook(
        process_command => ( undef, sub {
            my ( $self, $global_context, $command, $channel ) = @_;

            ($channel) = grep { $_->{name} eq $channel->name } Irssi::channels();
            if ($channel) {
                $channel->{server}->command("MSG $channel->{name} $command");
            }
        })
    );

    Irssi::print('mobirc is already started!');
    $mobirc->run_hook('run_component');

    Irssi::print('started mobirc') if $poe->kernel->alias_resolve('mobirc_httpd');
}

sub irssi_print_text {
    my $poe = sweet_args;
    my ($dest, $text, $stripped) = @{ $poe->args->[1] };

    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        App::Mobirc::Model::Channel->update_keyword_buffer($poe->heap->{mobirc}, $poe->heap->{__last_row});
    }
}

sub irssi_public {
    my $poe = sweet_args;
    my ($server, $msg, $nick, $address, $target) = @{ $poe->args->[1] };

    add_message( $poe, $target, $nick, $msg, 'public' );
}

sub irssi_private {}

sub irssi_own_public {
    my $poe = sweet_args;
    my ($server, $msg, $target) = @{ $poe->args->[1] };

    add_message( $poe, $target, $server->{nick}, $msg, 'public' );
}
sub irssi_own_private {}

sub irssi_join {
    my $poe = sweet_args;
    my ($server, $channel, $nick, $address) = @{ $poe->args->[1] };

    my $mobirc = $poe->heap->{mobirc};

    $channel = $mobirc->get_channel(decode_utf8 $channel->{name});

    unless ($server->{nick} eq $nick) {
        add_message( $poe, $channel, undef, "$nick joined", 'join');
    }
}

sub irssi_part {
    my $poe = sweet_args;
    my ($server, $channel, $nick, $address, $reason) = @{ $poe->args->[1] };

    my $mobirc = $poe->heap->{mobirc};

    $channel = normalize_channel_name( decode('utf-8', $channel) );
    if ($server->{nick} eq $nick) {
        delete $mobirc->{channels}->{$channel};
    }
    else {
        add_message($poe, $channel, undef, "$nick leaves", 'leave');
    }
}

sub irssi_quit {}
sub irssi_kick {}
sub irssi_nick {}
sub irssi_own_nick {}
sub irssi_invite {}

sub irssi_topic {
    my $poe = sweet_args;
    my ($server, $channel, $topic, $nick, $address) = @{ $poe->args->[1] };

    my $mobirc = $poe->heap->{mobirc};

    $channel = $mobirc->get_channel( normalize_channel_name(decode('utf-8', $channel)) );
    $channel->topic( decode('utf-8', $topic) );

    add_message($poe, $channel, undef, "$nick set topic: $topic", 'topic');
}

sub irssi_irc_op_public {}
sub irssi_irc_own_wall {}

sub irssi_irc_own_action {
    my $poe = sweet_args;
    my ($server, $msg, $target) = @{ $poe->args->[1] };

    $msg = sprintf('* %s %s', $server->{nick}, decode('utf-8', $msg));
    add_message( $poe, $target, '', $msg, 'ctcp_action');
}

sub irssi_irc_action {
    my $poe = sweet_args;
    my ($server, $msg, $nick, $address, $target) = @{ $poe->args->[1] };

    $msg = sprintf('* %s %s', $nick, decode('utf-8', $msg));
    add_message( $poe, $target, '', $msg, 'ctcp_action');
}

sub irssi_irc_own_notice {
    my $poe = sweet_args;
    my ($server, $msg, $target) = @{ $poe->args->[1] };

    add_message($poe, $target, $server->{nick}, $msg, 'notice');
}

sub irssi_irc_notice {
    my $poe = sweet_args;
    my ($server, $msg, $nick, $address, $target) = @{ $poe->args->[1] };

    add_message($poe, $target, $nick, $msg, 'notice');
}

sub irssi_irc_snotice {
    my $poe = sweet_args;
    my ($server, $msg, $nick, $address, $target) = @{ $poe->args->[1] };
    return unless $msg =~ /^\d/; # messages only

    add_message($poe, '*server*', undef, $msg, 'snotice');
}
sub irssi_irc_own_ctcp {}
sub irssi_irc_ctcp {}

sub poe_initialize_mobirc {
    my $poe = sweet_args;

    delete $poe->heap->{mobirc} if $poe->heap->{mobirc};

    my $conffname = Irssi::settings_get_str('mobirc_config_path');
    unless ($conffname) {
        Irssi::print('mobirc_config_path is not defined, please do "/set mobirc_config_path your_yaml_path" first');
        return;
    }
    unless (-f $conffname && -r _) {
        Irssi::print("file does not exist: $conffname");
        return;
    }

    my $mobirc;
    eval { $mobirc = App::Mobirc->new(config => $conffname) };
    if ($@) {
        Irssi::print("can't initialize mobirc: $@");
        return;
    }

    $poe->heap->{mobirc} = $mobirc;
    $poe->heap->{config} = $mobirc->config;

    $mobirc->add_channel( App::Mobirc::Model::Channel->new($mobirc, U '*server*') );
    for my $channel (Irssi::channels()) {
        my $channel_name = normalize_channel_name(decode_utf8 $channel->{name});
        $mobirc->add_channel( App::Mobirc::Model::Channel->new($mobirc, $channel_name) );
    }

    $mobirc;
}

sub poe_unload {
    my $kernel = $_[KERNEL];

    if (my $httpd_session = $kernel->alias_resolve('mobirc_httpd')) {
        $kernel->call( $httpd_session => 'shutdown' );
        delete $_[HEAP]->{mobirc};
        Irssi::print('stopped mobirc');
    }
}

sub script_unload {
    my ($kernel, $session, $args) = @_[KERNEL, SESSION, ARG1];
    my ($script) = @$args;

    if ($script =~ /mobirc/) {
        $kernel->call($session, 'unload');
    }
}

# XXX: to avoid weird warnings
{ package Irssi::Nick }

{
    no warnings 'redefine';
    sub add_message {
        my ($poe, @args) = @_;
        for my $arg (@args) {
            $arg = decode('utf-8', $arg) unless utf8::is_utf8($arg);
        }
        my ($channel, $who, $body, $class) = @args;

        $channel = $poe->heap->{mobirc}->get_channel(normalize_channel_name($channel))
            or return;

        my $message = App::Mobirc::Model::Message->new(
            who   => $who,
            body  => $body,
            class => $class,
        );
        $channel->add_message($poe->heap->{__last_row} = $message);
    }
}

=pod

=head1 NAME

mobirc.pl - irssi plugin for Mobirc

=head1 SYNOPSIS

    1.. copy (or link) this script into irssi script directory
    
    2. run irssi with Mobirc
    
       PERL5LIB=/path/to/mobirc/lib irssi
    
    3. start script in irssi
    
       /run mobirc
    
    4. set config.yaml path
    
       /set mobirc_config_path /path/to/your/config.yaml
    
    5. start mobirc
    
       /mobirc start

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Kazuhiro Osawa

Tokuhiro Matsuno

=cut


