package App::Mobirc::HTTPD::Template::Pages;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use List::Util qw/first/;
use HTML::Entities qw/encode_entities/;
use URI::Escape qw/uri_escape/;

my $css = <<'...';
<style type="text/css">
    .keyword_recent_notice {
        background-color: red;
    }

    .time {
        color: #004080;
    }
    .notice {
        color: #808080;
    }
    .join {
        color: #ccfece;
    }
    .leave {
        color: #cccefe;
    }
    .ctcp_action {
        color: #808080;
        font-style: italic;
    }
    .kick {
        color: #fc4efe;
    }
    .snotice {
        color: #408080;
    }
    .connect {
        color: #408080;
    }
    .reconnect {
        color: #408080;
    }

    .nick_normal { color: #000080; }
    .nick_myself { color: #6060a0; }
    .nick_subtech  { color: #FF0080; }
    .nick_initialJ { color: #00BF1A; }
</style>
...

template 'wrapper_mobile' => sub {
    my ($self, $mobile_agent, $code, $subtitle) = @_;
    my $encoding = $mobile_agent->can_display_utf8 ? 'UTF-8' : 'Shift_JIS';
    outs_raw qq{<?xml version=" 1.0 " encoding="$encoding"?>};
    html { attr { 'lang' => 'ja', 'xml:lang' => 'ja', xmlns => 'http://www.w3.org/1999/xhtml' }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=$encoding" } }
            meta { attr { 'http-equiv' => 'Cache-Control', content => 'max-age=0' } }
            meta { attr { name => 'robots', content => 'noindex, nofollow' } };
            if ($mobile_agent->user_agent =~ /(?:iPod|iPhone)/) {
                meta { attr { name => 'viewport', content => 'width=device-width' } }
                meta { attr { name => 'viewport', content => 'initial-scale=1.0, user-scalable=yes' } }
            }
            title {
                my $title = $subtitle ? "$subtitle - " : '';
                   $title .= "mobirc";
                   $title;
            }
            outs_raw $css; # FIXME: split to mobirc.css
        }
        body {
            $code->()

        }
    };
};

template 'footer' => sub {
    hr { };
    outs_raw '&#xE6E9;'; # TODO: pictogram::docomo { '8' }
    a { attr { 'accesskey' => "8", 'href' => "/"}
        'back to top'
    }
};

template 'topics' => sub {
    my ($self, $mobile_agent, $server) = @_;

    show 'wrapper_mobile', $mobile_agent, sub {
        for my $channel ( $server->channels ) {
            div { attr { class => 'OneTopic' }

                a { attr { href => sprintf('/channels/%s', uri_escape($channel->name)) }
                    $channel->name;
                } br { }

                span { $channel->topic } br { }
            }
        }

        show 'footer';
    }, 'topics';
};

template 'keyword' => sub {
    my ($self, $mobile_agent, $rows, $irc_nick) = @_;

    show 'wrapper_mobile', $mobile_agent, sub {
        a { attr { name => "1" } }
        a { attr { accesskey => '7', href => '#1' } };

        div { attr { class => 'ttlLv1' } 'keyword' };

        for my $row ( @$rows ) {
            show 'irc_message', $row, $irc_nick;
            outs '(';
                a { attr { 'href' => sprintf('/channels/%s', uri_escape( $row->channel->name)) }
                    $row->channel->name
                };
            outs ')';
            br { };
        }

        show 'footer';
    }, 'topics';
};

1;
