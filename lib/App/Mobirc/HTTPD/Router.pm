package App::Mobirc::HTTPD::Router;
use strict;
use warnings;
use Carp;
use HTTP::Response;
use URI::Escape;
use App::Mobirc::Util;

sub route {
    my ($class, $c, $uri) = @_;
    croak 'uri missing' unless $uri;

    my $root = $c->{config}->{httpd}->{root};
    $root =~ s!/$!!;
    $uri =~ s!^$root!!;
    # FIXME: it's for DoCoMoGUID. it may be too ugly.
    $uri =~ s/\?guid=on$//i;
    $uri =~ s!\&?guid=on\&?!!i; 

    if ( $uri eq '/' ) {
        return 'index';
    }
    elsif ( $uri eq '/topics' ) {
        return 'topics';
    }
    elsif ( $uri =~ m{^/recent(?:\?t=\d+)?$} ) {
        return 'recent';
    }
    elsif ( $uri =~ m{^/keyword(-recent)?(?:\?time=\d+)?$} ) {
        return 'keyword', $1 ? true : false;
    }
    elsif ($uri =~ m{^/channels(-recent)?/([^?]+)}) {
        my $recent_mode = $1 ? true : false;
        my $channel_name = $2;
        return 'show_channel', $recent_mode, uri_unescape($channel_name);
    }
    elsif ($uri eq '/clear_all_unread') {
        return 'clear_all_unread';
    }
    elsif ($uri =~ m{^/pc/menu(?:\?time=\d+)?$}) {
        return 'pc_menu';
    }
    elsif ($uri =~ '/jquery.js') {
        return 'static', 'jquery.js', 'application/javascript';
    }
    elsif ($uri =~ '/mobirc.js') {
        return 'static', 'mobirc.js', 'application/javascript';
    }
    elsif ($uri =~ '/style.css') {
        return 'static', 'style.css', 'text/css';
    } 
    elsif ($uri =~ m{^/(pc|mobirc|mobile).css}) {
        return 'static', "$1.css", 'text/css';
    }
    elsif ($uri =~ '/mobile.css') {
        return 'static', 'mobile.css', 'text/css';
    }
    else {
        # hook by plugins
        for my $code (@{$c->{global_context}->get_hook_codes('httpd')}) {
            my $response = $code->($c, $uri);
            if ($response) {
                return $response;
            }
        }

        # doesn't match.
        warn "dan the 404 not found: $uri" if $uri ne '/favicon.ico';
        my $response = HTTP::Response->new(404);
        $response->content("Dan the 404 not found: $uri");
        return $response;
    }
}

1;
