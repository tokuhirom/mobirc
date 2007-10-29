package Mobirc::HTTPD::Controller;
use strict;
use warnings;
use boolean ':all';

use Carp;
use CGI;
use Encode;
use Template;
use File::Spec;
use URI::Find;
use URI::Escape;
use HTTP::Response;
use HTML::Entities;
use Scalar::Util qw/blessed/;
use List::Util qw/first/;
use CGI::Cookie;

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
            ( $c->{irc_heap}->{channel_buffer}->{$a}->[-1]->{time} || 0 )
            <=> ( $c->{irc_heap}->{channel_buffer}->{$b}->[-1]->{time} || 0 )
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

    my $out = render(
        $c,
        'recent' => {
        },
    );

    # reset counter.
    for my $canon_channel ( sort keys %{ $c->{irc_heap}->{channel_name} } ) {
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
    $message = decode( $c->{config}->{httpd}->{charset}, $message );

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
            add_message(
                $c->{poe},
                $channel,
                $c->{irc_heap}->{irc}->nick_name,
                $message,
                'publicfromhttpd',
            );
        }
    }

    my $response = HTTP::Response->new(302);
    my $root = $c->{config}->{httpd}->{root};
    $root =~ s!/$!!;
    $response->push_header( 'Location' => $root . $c->{req}->uri . '?time=' . time); # TODO: must be absoulute url.
    return $response;
}


sub dispatch_show_channel {
    my ($class, $c, $recent_mode, $channel) = @_;

    DEBUG "show channel page: $channel";
    $channel = decode('utf8', $channel); # maybe $channel is not flagged utf8.

    my $out = render(
        $c,
        'show_channel' => {
            canon_channel  => canon_name($channel),
            channel        => $channel,
            subtitle       => compact_channel_name($channel),
            recent_mode    => $recent_mode,
        }
    );

    {
        my $canon_channel = canon_name($channel);

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
        title                => $c->{config}->{httpd}->{title},
        version              => $Mobirc::VERSION,

        %{ $c->{irc_heap} },

        %$args,
    };

    my $tt = Template->new(
        ABSOLUTE => 1,
        INCLUDE_PATH =>
          File::Spec->catfile( $c->{config}->{global}->{assets_dir}, 'tmpl', )
    );
    $tt->process(
        File::Spec->catfile(
            $c->{config}->{global}->{assets_dir},
            'tmpl', "$name.html"
        ),
        $args,
        \my $out
    ) or die $tt->error;

    DEBUG "rendering done";

    my $content = Encode::is_utf8($out) ? $out : decode( 'utf8', $out );
    $content = encode($c->{config}->{httpd}->{charset}, $content);

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => $c->{config}->{httpd}->{content_type} );
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

    URI::Find->new(
        sub {
            my ( $uri, $orig_uri ) = @_;

            my $out = qq{<a href="$uri" rel="nofollow">$orig_uri</a>};
            if ( $c->{config}->{httpd}->{au_pcsv} ) {
                $out .=
                  sprintf( '<a href="device:pcsiteviewer?url=%s">[PCSV]</a>',
                    $uri );
            }
            $out .=
              sprintf(
'<a href="http://mgw.hatena.ne.jp/?url=%s&noimage=0&split=1">[ph]</a>',
                uri_escape($uri) );
            return $out;
        }
    )->find( \$body );

    $body =~
s!\b(0\d{1,3})([-(]?)(\d{2,4})([-)]?)(\d{4})\b!<a href="tel:$1$3$5">$1$2$3$4$5</a>!g;
    $body =~
      s!\b(\w[\w.+=-]+\@[\w.-]+[\w]\.[\w]{2,4})\b!<a href="mailto:$1">$1</a>!g;

    $body = decorate_irc_color($body);

    return $body;
}

1;
