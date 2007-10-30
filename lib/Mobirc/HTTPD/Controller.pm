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
use CGI::Cookie;
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

    my $canon_channels = [
        reverse
          sort {
            (
                (
                    ( $c->{irc_heap}->{channel_buffer}->{$a} || [] )->[-1] || {}
                )->{time}
                  || 0
              ) <=> (
                (
                    ( $c->{irc_heap}->{channel_buffer}->{$b} || [] )->[-1] || {}
                )->{time}
                  || 0
              )
          }
          keys %{ $c->{irc_heap}->{channel_name} }
    ];

    return render(
        $c,
        'index' => {
            exists_recent_entries => (
                grep( $c->{irc_heap}->{unread_lines}->{$_}, keys %{ $c->{irc_heap}->{unread_lines} } )
                ? true
                : false
            ),
            canon_channels => $canon_channels,
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
      grep { @{ $c->{irc_heap}->{channel_recent}->{$_} || [] } }
      keys %{ $c->{irc_heap}->{channel_recent} };

    DEBUG "SCALAR " . scalar @unread_channels;

    for my $channel (@unread_channels) {
        push @target_channels, $channel;
        $log_counter += scalar @{ $c->{irc_heap}->{channel_recent}->{$channel} };

        if ($log_counter >= $c->{config}->{httpd}->{recent_log_per_page}) {
            $has_next_page = true;
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
    for my $canon_channel ( @target_channels ) {
        $c->{irc_heap}->{unread_lines}->{$canon_channel}   = 0;
        $c->{irc_heap}->{channel_recent}->{$canon_channel} = [];
    }

    return $out;
}

# topic on every channel
sub dispatch_topics {
    my ($class, $c) = @_;

    return render(
        $c,
        'topics' => { },
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
                add_message(
                    $c->{poe},
                    $channel,
                    decode( $c->{config}->{irc}->{incode}, $c->{irc_heap}->{irc}->nick_name),
                    $message,
                    'publicfromhttpd',
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

    my $out = render(
        $c,
        'keyword' => {
            rows => ($recent_mode ? $c->{irc_heap}->{keyword_recent} : $c->{irc_heap}->{keyword_buffer}),
        },
    );

    $c->{irc_heap}->{keyword_recent} = [];

    return $out;
}

sub dispatch_show_channel {
    my ($class, $c, $recent_mode, $channel) = @_;

    DEBUG "show channel page: $channel";
    $channel = decode('utf8', $channel); # maybe $channel is not flagged utf8.

    my $out = render(
        $c,
        'show_channel' => {
            canon_channel  => normalize_channel_name($channel),
            channel        => $channel,
            subtitle       => compact_channel_name($channel),
            recent_mode    => $recent_mode,
        }
    );

    {
        my $canon_channel = normalize_channel_name($channel);

        # clear unread counter
        $c->{irc_heap}->{unread_lines}->{$canon_channel} = 0;

        # clear recent messages buffer
        $c->{irc_heap}->{channel_recent}->{$canon_channel} = [];
    }

    return $out;
}

sub render {
    my ( $c, $name, $args ) = @_;

    croak "invalid args : $args" unless ref $args eq 'HASH';

    DEBUG "rendering template";

    # set default vars
    $args = {
        compact_channel_name => \&compact_channel_name,
        docroot              => $c->{config}->{httpd}->{root},
        render_line          => sub { render_line( $c, @_ ) },
        user_agent           => $c->{user_agent},
        mobile_agent         => $c->{mobile_agent},
        title                => $c->{config}->{httpd}->{title},
        version              => $Mobirc::VERSION,
        now                  => time(),

        %{ $c->{irc_heap} },

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

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => encode('utf8', $c->{config}->{httpd}->{content_type}) );
    $response->push_header('Content-Length' => length($content) );

    if ( $c->{config}->{httpd}->{use_cookie} ) {
        set_cookie( $c, $response );
    }

    $response->content( $content );

    return $response;
}

sub set_cookie {
    my $c        = shift;
    my $response = shift;

    my ( $user_info, ) =
      map { $_->{config} }
      first { $_->{module} =~ /Cookie$/ }
    @{ $c->{config}->{httpd}->{authorizer} };
    croak "Can't get user_info" unless $user_info;

    $response->push_header(
        'Set-Cookie' => CGI::Cookie->new(
            -name    => 'username',
            -value   => $user_info->{username},
            -expires => $c->{config}->{httpd}->{cookie_expires}
        )
    );
    $response->push_header(
        'Set-Cookie' => CGI::Cookie->new(
            -name    => 'passwd',
            -value   => $user_info->{username},
            -expires => $c->{config}->{httpd}->{cookie_expires}
        )
    );
}

sub render_line {
    my $c   = shift;
    my $row = shift;

    return "" unless $row;
    croak "must be hashref: $row" unless ref $row eq 'HASH';

    my ( $sec, $min, $hour ) = localtime($row->{time});
    my $ret = sprintf(qq!<span class="time"><span class="hour">%02d</span><span class="colon">:</span><span class="minute">%02d</span></span> !, $hour, $min);
    if ($row->{who}) {
        my $who_class = ($row->{who} eq $c->{irc_heap}->{irc}->nick_name)  ? 'nick_myself' : 'nick_normal';
        my $who = encode_entities($row->{who});
        $ret .= "<span class='$who_class'>($who)</span> ";
    }
    my $body = _process_body($c, $row->{msg});
    my $class = encode_entities($row->{class});
    $ret .= qq!<span class="$class">$body</span>!;

    return $ret;
}

sub _process_body {
    my ($c, $body) = @_;
    croak "message body should be flagged utf8: $body" unless Encode::is_utf8($body);

    $body = encode_entities($body, q(<>&"'));

    DEBUG "APPLY FILTERS";
    for my $filter ( @{ $c->{config}->{httpd}->{filter} || [] } ) {
        DEBUG "LOAD FILTER MODULE: $filter->{module}";

        $filter->{module}->use or die $@;
        $body = $filter->{module}->process($body, $filter->{config});
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
