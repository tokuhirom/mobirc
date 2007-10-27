package Mobirc::HTTPD;
use strict;
use warnings;
use boolean ':all';

use POE;
use POE::Sugar::Args;
use POE::Filter::HTTPD;
use POE::Component::Server::TCP;

use Carp;
use CGI;
use Encode;
use Template;
use File::Spec;
use URI::Find;
use URI::Escape;
use HTTP::Response;
use HTML::Entities;

use Mobirc::Util;

# TODO: should be configurable?
use constant cookie_ttl => 86400 * 3;    # 3 days

our $VERSION = 0.01;                     # TODO: should use $Mobirc::VERSION
our $GLOBAL_CONFIG;                      # TODO: should use HEAP.

sub init {
    my ( $class, $config ) = @_;

    my $session_id = POE::Component::Server::TCP->new(
        Alias        => 'mobirc_httpd',
        Port         => $config->{httpd}->{port},
        ClientFilter => 'POE::Filter::HTTPD',
        ClientInput  => \&on_web_request,
    );

    $GLOBAL_CONFIG = $config;
}

sub on_web_request {
    my ( $kernel, $heap, $request ) = @_[ KERNEL, HEAP, ARG0 ];
    my $poe        = sweet_args;
    my $user_agent = $request->{_headers}->{'user-agent'};

    my $config = $GLOBAL_CONFIG or die "config missing";

    if ( $ENV{DEBUG} ) {
        require Module::Reload;
        Module::Reload->check;
    }

    # Filter::HTTPD sometimes generates HTTP::Response objects.
    # They indicate (and contain the response for) errors that occur
    # while parsing the client's HTTP request.  It's easiest to send
    # the responses as they are and finish up.
    if ( $request->isa('HTTP::Response') ) {
        $heap->{client}->put($request);
        $kernel->yield('shutdown');
        return;
    }

    # cookie
    my $cookie_authorized;
    if ( $config->{httpd}->{use_cookie} ) {
        my %cookie;
        for ( split( /; */, $request->header('Cookie') ) ) {
            my ( $name, $value ) = split(/=/);
            $value =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('C', hex($1))/eg;
            $cookie{$name} = $value;
        }

        if (   $cookie{username} eq $config->{httpd}->{username}
            && $cookie{passwd} eq $config->{httpd}->{password} )
        {
            $cookie_authorized = true;
        }
    }

    # authorization
    unless ($cookie_authorized) {
        unless ( defined( $config->{httpd}->{au_subscriber_id} )
            && $request->header('x-up-subno')
            && $request->header('x-up-subno') eq $config->{httpd}->{au_subscriber_id} )
        {
            if ( defined( $config->{httpd}->{username} ) ) {
                unless ( $request->headers->authorization_basic eq
                    $config->{httpd}->{username} . ':' . $config->{httpd}->{password} )
                {
                    my $response = HTTP::Response->new(401);
                    $response->push_header(
                        WWW_Authenticate => qq(Basic Realm="keitairc") );
                    $heap->{client}->put($response);
                    $kernel->yield('shutdown');
                    return;
                }
            }
        }
    }

    my $uri = $request->uri;

    # store and remove attached options from uri
    my %option;
    {
        my @opts = split( ',', $uri );
        shift @opts;
        grep( $option{$_} = $_, @opts );
        $uri =~ s/,.*//;
    }

    my $content;
    my $ctx = {
        config => $config,
        poe    => $poe,
        req    => $request,
        channel_topics =>
          $poe->kernel->alias_resolve('irc_session')->get_heap->{channel_topic},
        channel_name =>
          $poe->kernel->alias_resolve('irc_session')->get_heap->{channel_name},
        channel_mtime =>
          $poe->kernel->alias_resolve('irc_session')->get_heap->{channel_mtime},
        channel_buffer => $poe->kernel->alias_resolve('irc_session')
          ->get_heap->{channel_buffer},
        channel_recent => $poe->kernel->alias_resolve('irc_session')
          ->get_heap->{channel_recent},
        unread_lines =>
          $poe->kernel->alias_resolve('irc_session')->get_heap->{unread_lines},
    };

    # process post request.
    if ( $request->method =~ /POST/i ) {
        post_dispatch($ctx);
    }

    if ( $uri eq '/' ) {
        $content = render_header( $ctx, $user_agent );

        if ( $option{recent} ) {
            DEBUG "RECENT";
            $content .= dispatch_recent($ctx);
        }
        elsif ( $option{topics} ) {
            DEBUG "TOPICS";
            $content .= dispatch_topics($ctx);
        }
        else {
            DEBUG "CHANNEL LIST";
            $content .= dispatch_index($ctx);
        }
    }
    else {
        DEBUG "CHANNEL DETAIL";
        $content =
          dispatch_show_channel( $ctx, $uri, $user_agent, \%option );
    }

    $content .= render_footer();

    my $response = HTTP::Response->new(200);

    if ( $config->{httpd}->{use_cookie} ) {
        set_cookie( $ctx, $response );
    }

    $response->push_header( 'Content-type', 'text/html; charset=Shift_JIS' ); # TODO: should be configurable
    $response->content( encode( $config->{httpd}->{charset}, $content ) );
    $heap->{client}->put($response);
    $kernel->yield('shutdown');
}

sub post_dispatch {
    my ( $c, ) = @_;

    my $r       = CGI->new( $c->{req}->content );
    my $message = $r->param('m');
    $message = decode( $c->{config}->{httpd}->{charset}, $message );

    if ($message) {
        my $uri = $c->{req}->uri;
        $uri =~ s|^/||;
        my $channel = uri_unescape($uri);
        $c->{poe}->kernel->post( 'keitairc_irc', privmsg => $channel => $message );
        add_message(
            $c->{poe},
            decode( $c->{config}->{irc}->{incode}, $channel ),
            $c->{config}->{irc}->{nick}, $message
        );
    }
}

sub dispatch_index {
    my $c = shift;
    my $buf;
    my $accesskey = 1;
    my $channel;

    my %channel_name = %{ $c->{channel_name} };
    my $docroot      = $c->{config}->{httpd}->{root};

    for my $canon_channel (
        sort { $c->{channel_mtime}->{$b} <=> $c->{channel_mtime}->{$a}; }
        ( keys(%channel_name) ) )
    {
        $channel = $channel_name{$canon_channel};

        $buf .= label($accesskey);

        if ( $accesskey < 10 ) {
            $buf .= sprintf( '<a accesskey="%1d" href="%s%s">%s</a>',
                $accesskey, $docroot, uri_escape($channel),
                compact_channel_name($channel) );
        }
        else {
            $buf .= sprintf( '<a href="%s%s">%s</a>',
                $docroot, uri_escape($channel),
                compact_channel_name($channel) );
        }

        $accesskey++;

        if ( $c->{unread_lines}->{$canon_channel} ) {
            $buf .= sprintf( ' <a href="%s%s,recent">%s</a>',
                $docroot, uri_escape($channel),
                $c->{unread_lines}->{$canon_channel} );
        }
        $buf .= '<br>';
    }

    $buf .= qq(0 <a href="$docroot" accesskey="0">refresh list</a><br>);

    if ( grep( $c->{unread_lines}->{$_}, keys %{ $c->{unread_lines} } ) ) {
        $buf .= qq(* <a href="$docroot,recent" accesskey="*">recent</a><br>);
    }

    $buf .= qq(# <a href="$docroot,topics" accesskey="#">topics</a><br>);

    $buf .= qq( - keitairc $VERSION);
    $buf;
}

# recent messages on every channel
sub dispatch_recent {
    my $c = shift;

    my $out = render(
        $c,
        'recent' => {
            docroot        => $c->{config}->{httpd}->{root},
            channel_name   => $c->{channel_name},
            render_list    => sub { render_list( $c, @_ ) },
            channel_recent => $c->{channel_recent},
        },
    );

    # reset counter.
    for my $canon_channel ( sort keys %{ $c->{channel_name} } ) {
        $c->{unread_lines}->{$canon_channel}   = 0;
        $c->{channel_recent}->{$canon_channel} = '';
    }

    return $out;
}

# topic on every channel
sub dispatch_topics {
    my $c = shift;

    return render(
        $c,
        'topics' => {
            docroot      => $c->{config}->{httpd}->{root},
            channel_name => $c->{channel_name},
            topic        => $c->{channel_topics},
        },
    );
}

sub dispatch_show_channel {
    my $c          = shift;
    my $uri        = shift;
    my $user_agent = shift;
    my $option     = shift;
    my %option     = %$option;

    # channel conversation
    $uri =~ s|^/||;

    # RFC 2811:
    # Apart from the the requirement that the first character
    # being either '&', '#', '+' or '!' (hereafter called "channel
    # prefix"). The only restriction on a channel name is that it
    # SHALL NOT contain any spaces (' '), a control G (^G or ASCII
    # 7), a comma (',' which is used as a list item separator by
    # the protocol).  Also, a colon (':') is used as a delimiter
    # for the channel mask.  The exact syntax of a channel name is
    # defined in "IRC Server Protocol" [IRC-SERVER].
    #
    # so we use white space as separator character of channel name
    # and command argument.

    my $channel = uri_unescape($uri);

    {
        my $canon_channel = canon_name($channel);
        # clear unread counter
        $c->{unread_lines}->{$canon_channel} = 0;
        # clear recent messages buffer
        $c->{channel_recent}->{$canon_channel} = '';
    }

    my $header =
      render_header( $c, $user_agent, compact_channel_name($channel) );

    return render(
        $c,
        'show_channel' => {
            docroot        => $c->{config}->{httpd}->{root},
            channel_name   => $c->{channel_name},
            canon_channel  => canon_name($channel),
            channel        => $channel,
            channel_buffer => $c->{channel_buffer},
            render_list    => sub { render_list( $c, @_ ) },
            header         => $header,
            channel_recent => $c->{channel_recent},
        }
    );
}

sub render_header {
    my $c          = shift;
    my $user_agent = shift;
    my $subtitle   = shift;

    DEBUG "RENDER HEADER";

    return render(
        $c,
        'header' => {
            user_agent => $user_agent,
            subtitle   => $subtitle,
            title      => $c->{config}->{httpd}->{title},
        }
    );
}

sub render {
    my ($c, $name, $args) = @_;

    croak "invalid args : $args" unless ref $args eq 'HASH';

    my $tt = Template->new(
        ABSOLUTE     => 1,
        INCLUDE_PATH => File::Spec->catfile(
            $c->{config}->{global}->{assets_dir},
            'tmpl', 'include'
        )
    );
    $tt->process(
        File::Spec->catfile($c->{config}->{global}->{assets_dir}, 'tmpl', "$name.html"), $args, \my $out
    ) or die $tt->error;

    return decode('utf8', $out);
}

sub render_footer {
    return '</body></html>';
}

sub set_cookie {
    my $c        = shift;
    my $response = shift;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) =
      localtime( time + cookie_ttl );

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
            $c->{config}->{httpd}->{username}, $expiration
        )
    );
    $response->push_header(
        'Set-Cookie',
        sprintf(
            "passwd=%s; expires=%s; \n",
            $c->{config}->{httpd}->{password}, $expiration
        )
    );
}

sub render_list {
    my $c   = shift;
    my $src = shift;

    croak "must be flagged utf8" unless Encode::is_utf8($src);

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

