package Mobirc::HTTPD::Controller;
use strict;
use warnings;

use Carp;
use CGI;
use Encode;
use Template;
use File::Spec;
use URI::Escape;
use HTTP::Response;
use HTML::Entities;
use Scalar::Util qw/blessed/;
use List::Util qw/first/;
use Template::Provider::Encoding;

use Mobirc;
use Mobirc::Util;

sub call {
    my ($class, $method, @args) = @_;
    DEBUG "CALL METHOD $method with @args";
    $class->$method(@args);
}

# this module contains MVC's C.

sub dispatch_index {
    my ($class, $c) = @_;

    my $channels = [
        reverse
          map {
              $_->[0];
          }
          sort {
              $a->[1] <=> $b->[1] ||
              $a->[2] <=> $b->[2]
          }
          map {
              my $unl  = $_->unread_lines ? 1 : 0;
              my $buf  = $_->message_log || [];
              my $last =
                (grep {
                    $_->{class} eq "public" ||
                    $_->{class} eq "notice"
                } @{ $buf })[-1] || {};
              my $time = ($last->{time} || 0);
              [$_, $unl, $time];
          }
          $c->{global_context}->channels
    ];

    my $keyword_recent_num = $c->{global_context}->get_channel(U '*keyword*')->unread_lines;

    return render(
        $c,
        'index' => {
            exists_recent_entries => (
                grep( $_->unread_lines, $c->{global_context}->channels )
                ? true
                : false
            ),
            keyword_recent_num => $keyword_recent_num,
            channels => $channels,
        }
    );
}

# recent messages on every channel
sub dispatch_recent {
    my ($class, $c) = @_;

    my @target_channels;
    my $log_counter = 0;
    my $has_next_page = false;

    my @unread_channels =
      grep { $_->unread_lines }
      $c->{global_context}->channels;

    DEBUG "SCALAR " . scalar @unread_channels;

    for my $channel (@unread_channels) {
        push @target_channels, $channel;
        $log_counter += scalar @{ $channel->recent_log };

        if ($log_counter >= $c->{config}->{httpd}->{recent_log_per_page}) {
            $has_next_page = true; # FIXME: BUGGY
            last;
        }
    }

    my $out = render(
        $c,
        'recent' => {
            target_channels => \@target_channels,
            has_next_page   => $has_next_page,
        },
    );

    # reset counter.
    for my $channel ( @target_channels ) {
        $channel->clear_unread;
    }

    return $out;
}

# topic on every channel
sub dispatch_topics {
    my ($class, $c) = @_;

    return render(
        $c,
        'topics' => {
            channels => [$c->{global_context}->channels],
        },
    );
}

sub post_dispatch_show_channel {
    my ( $class, $c, $recent_mode, $channel) = @_;

    $channel = decode('utf8', $channel); # maybe $channel is not flagged utf8.

    my $r       = CGI->new( $c->{req}->content );
    my $message = $r->param('msg');
    $message = decode( _get_charset($c), $message );

    DEBUG "POST MESSAGE $message";

    if ($message) {
        if ($message =~ m{^/}) {
            DEBUG "SENDING COMMAND";
            $message =~ s!^/!!g;

            my @args =
              map { encode( $c->{config}->{irc}->{incode}, $_ ) } split /\s+/,
              $message;

            $c->{poe}->kernel->post('mobirc_irc', @args);
        } else {
            DEBUG "NORMAL PRIVMSG";

            $c->{poe}->kernel->post( 'mobirc_irc',
                privmsg => encode( $c->{config}->{irc}->{incode}, $channel ) =>
                encode( $c->{config}->{irc}->{incode}, $message ) );

            DEBUG "Sending message $message";
            if ($c->{config}->{httpd}->{echo} eq true) {
                $c->{global_context}->get_channel($channel)->add_message(
                    Mobirc::Message->new(
                        who => decode(
                            $c->{config}->{irc}->{incode},
                            $c->{irc_nick}
                        ),
                        body  => $message,
                        class => 'publicfromhttpd',
                    )
                );
            }
        }
    }

    my $response = HTTP::Response->new(302);
    my $root = $c->{config}->{httpd}->{root};
    $root =~ s!/$!!;
    my $path = $c->{req}->uri;
    $path =~ s/#/%23/;
    $response->push_header( 'Location' => $root . $path . '?time=' . time); # TODO: must be absoulute url.
    return $response;
}

sub dispatch_keyword {
    my ($class, $c, $recent_mode) = @_;

    my $channel = $c->{global_context}->get_channel(U '*keyword*');

    my $out = render(
        $c,
        'keyword' => {
            rows => ($recent_mode ? $channel->recent_log : $channel->message_log),
        },
    );

    $channel->clear_unread;

    return $out;
}

sub dispatch_show_channel {
    my ($class, $c, $recent_mode, $channel_name) = @_;

    DEBUG "show channel page: $channel_name";
    $channel_name = decode('utf8', $channel_name); # maybe $channel_name is not flagged utf8.

    my $channel = $c->{global_context}->get_channel($channel_name);

    my $out = render(
        $c,
        'show_channel' => {
            channel        => $channel,
            recent_mode    => $recent_mode,
        }
    );

    $channel->clear_unread;

    return $out;
}

sub render {
    my ( $c, $name, $args ) = @_;

    croak "invalid args : $args" unless ref $args eq 'HASH';

    DEBUG "rendering template";

    # set default vars
    $args = {
        docroot              => $c->{config}->{httpd}->{root},
        render_line          => sub { render_line( $c, @_ ) },
        user_agent           => $c->{user_agent},
        mobile_agent         => $c->{mobile_agent},
        title                => $c->{config}->{httpd}->{title},
        version              => $Mobirc::VERSION,
        now                  => time(),

        %$args,
    };

    my $tt = Template->new(
        LOAD_TEMPLATES => [
            Template::Provider::Encoding->new(
                ABSOLUTE => 1,
                INCLUDE_PATH =>
                  File::Spec->catfile( $c->{config}->{global}->{assets_dir},
                    'tmpl', )
            )
        ],
    );
    $tt->process("$name.html", $args, \my $out)
        or die $tt->error;

    DEBUG "rendering done";

    my $content = encode( _get_charset($c), $out);
    $content = _html_filter($c, $content);

    # change content type for docomo
    # FIXME: hmm... should be in the plugin?
    local $c->{config}->{httpd}->{content_type} = 'application/xhtml+xml' if $c->{mobile_agent}->is_docomo; ## no critic.

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => encode('utf8', $c->{config}->{httpd}->{content_type}) );
    $response->push_header('Content-Length' => length($content) );

    $response->content( $content );

    for my $code (@{$c->{global_context}->get_hook_codes('response_filter')}) {
        $code->($c, $response);
    }

    return $response;
}

sub _html_filter {
    my $c = shift;
    my $content = shift;

    for my $code (@{$c->{global_context}->get_hook_codes('html_filter')}) {
        $content = $code->($c, $content);
    }

    $content;
}

sub render_line {
    my $c   = shift;
    my $message = shift;

    return "" unless $message;
    croak "must be hashref: $message" unless ref $message eq 'Mobirc::Message';

    my ( $sec, $min, $hour ) = localtime($message->time);
    my $ret = sprintf(qq!<span class="time"><span class="hour">%02d</span><span class="colon">:</span><span class="minute">%02d</span></span> !, $hour, $min);
    if ($message->who) {
        my $who_class = ($message->who eq $c->{irc_nick})  ? 'nick_myself' : 'nick_normal';
        my $who = encode_entities($message->who);
        $ret .= "<span class='$who_class'>($who)</span> ";
    }
    my $body = _process_body($c, $message->body);
    my $class = encode_entities($message->class);
    $ret .= qq!<span class="$class">$body</span>!;

    return $ret;
}

sub _process_body {
    my ($c, $body) = @_;
    croak "message body should be flagged utf8: $body" unless Encode::is_utf8($body);

    $body = encode_entities($body, q(<>&"'));

    DEBUG "APPLY FILTERS";
    for my $filter ( @{ $c->{global_context}->get_hook_codes('message_body_filter') || [] } ) {
        $body = $filter->($body);
    }

    return $body;
}

sub _get_charset {
    my ($c, ) = @_;

    my $charset = $c->{config}->{httpd}->{charset};

    if ($charset =~ /^shift_jis-.+/) {
        require Encode::JP::Mobile;
    }

    if ($charset eq 'shift_jis-mobile-auto') {
        my $agent = $c->{mobile_agent};
        if ($agent->is_non_mobile) {
            $charset = 'cp932';
        } else {
            $charset = 'shift_jis-' . lc $agent->carrier_longname;
        }
    }

    DEBUG "use charset: $charset";

    return $charset;
}

1;
