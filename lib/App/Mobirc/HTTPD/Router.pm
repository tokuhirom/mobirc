package App::Mobirc::HTTPD::Router;
use strict;
use warnings;
use Carp;
use HTTP::Response;
use URI::Escape;
use App::Mobirc::Util;
use Encode;

sub route {
    my ($class, $req,) = @_;

    my $root = App::Mobirc->context->config->{httpd}->{root};
    $root =~ s!/$!!;
    my $uri = $req->uri->path;
    $uri =~ s!^$root!!;

    if ( $uri eq '/'  || $uri eq '' ) {
        return 'Mobile', 'index';
    }
    elsif ( $uri eq '/ajax/' ) {
        return 'Ajax', 'ajax_base';
    }
    elsif ($uri =~ m{^/ajax/channel/([^?]+)}) {
        my $channel_name = $1;
        return 'Ajax', 'ajax_channel', decode_utf8(uri_unescape($channel_name));
    }
    elsif ( $uri eq '/topics' ) {
        return 'Mobile', 'topics';
    }
    elsif ( $uri eq '/recent' ) {
        return 'Mobile', 'recent';
    }
    elsif ( $uri eq '/keyword' ) {
        return 'Mobile', 'keyword', $1 ? true : false;
    }
    elsif ($uri =~ m{^/channels/(.+)}) {
        my $channel_name = $1;
        return 'Mobile', 'show_channel', decode_utf8(uri_unescape($channel_name));
    }
    elsif ($uri eq '/clear_all_unread') {
        return 'Mobile', 'clear_all_unread';
    }
    elsif ($uri eq '/ajax/menu') {
        return 'Ajax', 'ajax_menu';
    }
    elsif ($uri eq '/ajax/keyword') {
        return 'Ajax', 'keyword';
    }
    elsif ($uri eq '/jquery.js') {
        return 'Static', 'deliver', 'jquery.js', 'application/javascript';
    }
    elsif ($uri eq '/mobirc.js') {
        return 'Static', 'deliver', 'mobirc.js', 'application/javascript';
    }
    elsif ($uri =~ m{^/(pc|mobirc|mobile).css}) {
        return 'Static', 'deliver', "$1.css", 'text/css';
    }
    else {
        # hook by plugins
        for my $code (@{App::Mobirc->context->get_hook_codes('httpd')}) {
            my $response = $code->($uri); # XXX broken
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
