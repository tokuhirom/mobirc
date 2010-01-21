use strict;
use warnings;
use Test::Requires 'POE::Component::Server::IRC', 'Test::TCP', 'POE';
use App::Mobirc;
use AE;
use AnyEvent::IRC::Client;
use Test::More;
use App::Mobirc::Util qw/U/;
use AnyEvent::IRC::Util qw/encode_ctcp/;

test_tcp(
    client => sub {
        my $port = shift;
        my $cv = AE::cv();

        # create mobirc.
        my $c = App::Mobirc->new(
            config => {
                plugin => [
                    {
                        module => 'Component::IRCClient',
                        config => {
                            server => 'localhost',
                            port   => $port,
                            nick   => 'john',
                        },
                    }
                ],
            }
        );
        $c->run_hook('run_component');

        my $i = 0;
        my @holder;

        # wait connection: mobirc to ircd.
        my $t; $t = AE::timer(0, 1, sub {
            return unless $c->irc_component->conn->registered();

            $c->irc_component()->conn()->send_msg("JOIN" => '#foo');
            $c->irc_component()->conn()->send_msg("JOIN" => '#finished');

            # tester thread
            my $irc = AnyEvent::IRC::Client->new();
            $irc->connect(
                '127.0.0.1',
                $port,
                {
                    nick    => 'tester',
                    user    => 'tester',
                    timeout => 1,
                    password => 'fishdont',
                }
            );
            $irc->reg_cb(
                irc_001 => sub {
                    diag "irc_001";
                    $irc->send_msg("JOIN", '#foo');
                },
                join => sub {
                    my ($irc, $nick, $chan, $is_me) = @_;
                    diag "join($nick, $chan, $is_me)";
                    if ($chan eq '#foo') {
                        # just want delay

                        my $t; $t = AE::timer(1, 0, sub {
                            diag "INJECT MESSAGE";
                            $irc->send_msg("PRIVMSG", 'john', "PRIVATE TALK");
                            $irc->send_msg("PRIVMSG", '#foo', "THIS IS PRIVMSG");
                            $irc->send_msg("NOTICE", '#foo', "THIS IS NOTICE");
                            $irc->send_msg("PRIVMSG", '#foo', "THIS IS にほんご");
                            $irc->send_msg("PRIVMSG", '#foo', encode_ctcp(['ACTION', "too"]));
                            $irc->send_msg("PRIVMSG", '#foo', "DNBK");
                            # $c->run_hook_first('process_command' => '/me hey', $c->get_channel('#foo'));
                            # $c->run_hook('process_command' => 'ah,ah', '#foo');
                            $irc->send_msg("JOIN", '#finished');
                            undef $t;
                        });
                        push @holder, $t;
                    } elsif ($chan eq '#finished') {
                        my $t; $t = AE::timer(1, 0, sub {
                            $irc->send_msg("PRIVMSG", '#finished', "FINISHED!");
                            undef $t;
                        });
                        push @holder, $t;
                    }
                },
            );

            undef $t; # clear timer
        });

        # finalizer thread
        my $finalizer = AE::timer(0, 5, sub {
            diag "Testing";
            my $chan = $c->get_channel('#finished');
            if (scalar(@{$chan->message_log()}) > 0) {
                $cv->send(1);
            }
        });

        $cv->recv();

        diag "finished";
        subtest '#foo' => sub {
            my $i = 0;
            my @logs = $c->get_channel('#foo')->message_log();
            is $logs[$i]->class, 'join';
            is $logs[$i++]->body, 'tester joined';
            is $logs[$i]->class, 'public';
            is $logs[$i++]->body, 'THIS IS PRIVMSG';
            is $logs[$i]->class, 'notice';
            is $logs[$i++]->body, 'THIS IS NOTICE';
            is $logs[$i]->class, 'public';
            is $logs[$i++]->body, U('THIS IS にほんご');
            is $logs[$i]->class, 'ctcp_action';
            is $logs[$i++]->body, U('* tester too');
            is $logs[$i]->class, 'public';
            is $logs[$i++]->body, U('DNBK');
            is $logs[$i]->class, 'kick';
            is $logs[$i++]->body, U('anyone has kicked kan(kan)');
            is $logs[$i]->class, 'topic';
            is $logs[$i++]->body, U('SERVER set topic: *** is GOD');
            is $logs[$i]->class, 'leave';
            is $logs[$i++]->body, U('parter leaves(parter)');
            is(join(',', map { $_->class } @logs), 'join,public,notice,public,ctcp_action,public,kick,topic,leave');
            done_testing;
        };
        TODO: {
            local $TODO = 'support private talk';
            my @logs = $c->get_channel('tester')->message_log();
            is join("", map { $_->body } @logs), 'PRIVATE TALK';
        }
        subtest 'finalized' => sub {
            my @logs = $c->get_channel('#finished')->message_log();
            like join("\n", map { $_->body } @logs), qr/FINISHED!/;
            is join(',', sort { $a cmp $b } map { $_->name } $c->server->channels), "#finished,#foo,*server*,john,tester", 'channels';
            done_testing;
        };

        done_testing;
    },
    server => sub {
        my $port = shift;


        my $ircd = POE::Component::Server::IRC->spawn(
            config => {
                servername => 'simple.poco.server.irc',
                nicklen    => 15,
                network    => 'SimpleNET',
                antiflood  => 0,
            }
        );
        POE::Session->create(
            inline_states => {
                _start => sub {
                    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
                    $heap->{ircd}->yield('register');

                    $ircd->yield( add_spoofed_nick => { nick => 'SERVER' } );
                    $ircd->yield(daemon_cmd_join => 'SERVER', '#foo');
                    $ircd->yield( add_spoofed_nick => { nick => 'kan' } );
                    $ircd->yield(daemon_cmd_join => 'kan', '#foo');
                    $ircd->yield( add_spoofed_nick => { nick => 'parter' } );
                    $ircd->yield(daemon_cmd_join => 'parter', '#foo');

                    # Anyone connecting from the loopback gets spoofed hostname
                    $heap->{ircd}->add_auth(
                        mask     => '*@localhost',
                        spoof    => 'm33p.com',
                        no_tilde => 1
                    );

                    # We have to add an auth as we have specified one above.
                    $heap->{ircd}->add_auth( mask => '*@*' );

                    # Start a listener on the 'standard' IRC port.
                    $heap->{ircd}->add_listener(
                        port => $port,
                        antiflood => '0',
                    );

                    # Add an operator who can connect from localhost
                    $heap->{ircd}->add_operator(
                        { username => 'tester', password => 'fishdont' } );

                    undef;
                },
                _default => sub {
                    my ( $event, $args ) = @_[ ARG0 .. $#_ ];
                    print STDOUT "SERVER: $event: ";
                    foreach (@$args) {
                      SWITCH: {
                            if ( ref($_) eq 'ARRAY' ) {
                                print STDOUT "[", join( ", ", @$_ ), "] ";
                                last SWITCH;
                            }
                            if ( ref($_) eq 'HASH' ) {
                                print STDOUT "{", join( ", ", %$_ ), "} ";
                                last SWITCH;
                            }
                            print STDOUT "'$_' ";
                        }
                    }
                    print STDOUT "\n";
                    return 0;    # Don't handle signals.
                },
              # ircd_join => sub {
              # },
              # ircd_daemon_public => sub {
              #     warn "PRIVMSG : " . $_[ARG0];
              # },
                ircd_daemon_public => sub {
                    my ($heap, $who, $chan, $msg) = @_[HEAP, ARG0..$#_];
                    if ($msg eq 'DNBK') {
                        $heap->{ircd}->yield(daemon_cmd_kick => 'SERVER', '#foo', 'kan');
                        $heap->{ircd}->yield(daemon_cmd_topic => 'SERVER', '#foo', '*** is GOD');
                        $heap->{ircd}->yield(daemon_cmd_part => 'parter', '#foo');
                    }
                },
            },
            heap => { ircd => $ircd },
        );
        POE::Kernel->run();
    },
);
