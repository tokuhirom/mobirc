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

    return render(
        $c,
        'index' => {
            exists_recent_entries => (
                grep( $c->{irc_heap}->{unread_lines}->{$_}, keys %{ $c->{irc_heap}->{unread_lines} } )
                ? true
                : false
            ),
            canon_channels => [
                reverse
                  sort {
                    $c->{irc_heap}->{channel_mtime}->{$a} <=> $c->{irc_heap}->{channel_mtime}->{$b}
                  }
                  keys %{ $c->{irc_heap}->{channel_name} }
            ],
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

    my $r       = CGI->new( $c->{req}->content );
    my $message = $r->param('msg');
    $message = decode( $c->{config}->{httpd}->{charset}, $message );

    DEBUG "POST MESSAGE $message";

    if ($message) {
        $c->{poe}->kernel->post( 'keitairc_irc', privmsg => $channel => $message );

        add_message(
            $c->{poe},
            decode( $c->{config}->{irc}->{incode}, $channel ),
            $c->{config}->{irc}->{nick}, $message
        );
    }

    my $response = HTTP::Response->new(302);
    $response->push_header( 'Location' => $c->{req}->uri . '?time=' . time); # TODO: must be absoulute url.
    return $response;
}


sub dispatch_show_channel {
    my ($class, $c, $recent_mode, $channel) = @_;

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

    # set default vars
    $args = {
        compact_channel_name => \&compact_channel_name,
        docroot              => $c->{config}->{httpd}->{root},
        render_list          => sub { render_list( $c, @_ ) },
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

    my $content = decode( 'utf8', $out );
    $content = encode($c->{config}->{httpd}->{charset}, $content);

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type', 'text/html; charset=Shift_JIS' ); # TODO: should be configurable
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

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) =
      localtime( time + $c->{httpd}->{cookie_ttl} );

    my ( $user_info, ) =
      map { $_->{config} }
      first { $_->{module} =~ /Cookie$/ }
    @{ $c->{config}->{httpd}->{authorizer} };
    croak "Can't get user_info" unless $user_info;

    my $expiration = sprintf(
        '%.3s, %.2d-%.3s-%.4s %.2d:%.2d:%.2d',
        qw(Sun Mon Tue Wed Thu Fri Sat) [$wday],
        $mday,
        qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) [$mon],
        $year + 1900,
        $hour,
        $min,
        $sec
    );
    $response->push_header(
        'Set-Cookie',
        sprintf(
            "username=%s; expires=%s; \n",
            $user_info->{username}, $expiration
        )
    );
    $response->push_header(
        'Set-Cookie',
        sprintf(
            "passwd=%s; expires=%s; \n",
            $user_info->{password}, $expiration
        )
    );
}

sub render_list {
    my $c   = shift;
    my $src = shift;

    return "" unless $src;
    croak "must be flagged utf8: $src" unless Encode::is_utf8($src);

    $src = join "\n", reverse split /\n/, $src;

    $src = encode_entities($src);

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
    )->find( \$src );

    $src =~
s!\b(0\d{1,3})([-(]?)(\d{2,4})([-)]?)(\d{4})\b!<a href="tel:$1$3$5">$1$2$3$4$5</a>!g;
    $src =~
      s!\b(\w[\w.+=-]+\@[\w.-]+[\w]\.[\w]{2,4})\b!<a href="mailto:$1">$1</a>!g;

    $src =~ s!\n!<br />\n!g;

    return $src;
}

1;
