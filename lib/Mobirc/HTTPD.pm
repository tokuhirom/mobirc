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
use Scalar::Util qw/blessed/;

use Mobirc;
use Mobirc::Util;

# TODO: should be configurable?
use constant cookie_ttl => 86400 * 3;    # 3 days

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
            && $request->header('x-up-subno') eq
            $config->{httpd}->{au_subscriber_id} )
        {
            if ( defined( $config->{httpd}->{username} ) ) {
                unless ( $request->headers->authorization_basic eq
                      $config->{httpd}->{username} . ':'
                    . $config->{httpd}->{password} )
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

    my $ctx = {
        config     => $config,
        poe        => $poe,
        req        => $request,
        user_agent => $user_agent,
        irc_heap   => $poe->kernel->alias_resolve('irc_session')->get_heap,
    };

    my $response = process_request($ctx, $request->uri);

    $poe->heap->{client}->put($response);
    $poe->kernel->yield('shutdown');
}

sub process_request {
    my ($c, $uri) = @_;
    croak 'uri missing' unless $uri;

    my ($meth, @args) = route($c, $uri);

    if (blessed $meth && $meth->isa('HTTP::Response')) {
        return $meth;
    }

    {
        no strict 'refs'; ## no critic.
        if ( $c->{req}->method =~ /POST/i && *{__PACKAGE__ . "::post_dispatch_$meth"}) {
            return &{__PACKAGE__ . "::post_dispatch_$meth"}($c, @args);
        } else {
            return &{__PACKAGE__ . "::dispatch_$meth"}($c, @args);
        }
    }
}

sub route {
    my ($c, $uri) = @_;
    croak 'uri missing' unless $uri;

    if ( $uri eq '/' ) {
        return 'index';
    }
    elsif ( $uri eq '/topics' ) {
        return 'topics';
    }
    elsif ( $uri eq '/recent' ) {
        return 'recent';
    }
    elsif ($uri =~ m{^/channels(-recent)?/([^?]+)(?:\?time=\d+)?$}) {
        my $recent_mode = $1 ? true : false;
        my $channel_name = $2;
        return 'show_channel', $recent_mode, uri_unescape($channel_name);
    } else {
        warn "dan the 404 not found: $uri";
        my $response = HTTP::Response->new(404);
        $response->content("Dan the 404 not found: $uri");
        return $response;
    }
}

sub post_dispatch_show_channel {
    my ( $c, $recent_mode, $channel) = @_;

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

sub dispatch_index {
    my $c = shift;

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
    my $c = shift;

    my $out = render(
        $c,
        'recent' => {
        },
    );

    # reset counter.
    for my $canon_channel ( sort keys %{ $c->{irc_heap}->{channel_name} } ) {
        $c->{irc_heap}->{unread_lines}->{$canon_channel}   = 0;
        $c->{irc_heap}->{channel_recent}->{$canon_channel} = '';
    }

    return $out;
}

# topic on every channel
sub dispatch_topics {
    my $c = shift;

    return render(
        $c,
        'topics' => {
        },
    );
}

sub dispatch_show_channel {
    my ($c, $recent_mode, $channel) = @_;

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
        $c->{irc_heap}->{channel_recent}->{$canon_channel} = '';
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

