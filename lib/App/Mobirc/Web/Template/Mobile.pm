package App::Mobirc::Web::Template::Mobile;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use List::Util qw/first/;
use HTML::Entities qw/encode_entities/;
use URI::Escape qw/uri_escape_utf8/;
use App::Mobirc::Pictogram;

sub mobile_agent {
    App::Mobirc::Web::Handler->web_context()->req->mobile_agent()
}

template 'mobile/wrapper_mobile' => sub {
    my ($self, $code, $subtitle) = @_;
    my $encoding = 'UTF-8';
    xml_decl { 'xml', version => '1.0', encoding => $encoding };
    outs_raw qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};
    html { attr { 'lang' => 'ja', 'xml:lang' => 'ja', xmlns => 'http://www.w3.org/1999/xhtml' }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=$encoding" } }
            meta { attr { 'http-equiv' => 'Cache-Control', content => 'max-age=0' } }
            meta { attr { name => 'robots', content => 'noindex, nofollow' } }
            link { attr { rel => 'stylesheet', href => '/static/mobirc.css', type=> "text/css"} };
            link { attr { rel => 'stylesheet', href => '/static/mobile.css', type=> "text/css"} };
            if (mobile_agent()->user_agent =~ /(?:iPod|iPhone)/) {
                meta { attr { name => 'viewport', content => 'width=device-width' } }
                meta { attr { name => 'viewport', content => 'initial-scale=1.0, user-scalable=yes' } }
            }
            title {
                my $title = $subtitle ? "$subtitle - " : '';
                   $title .= "mobirc";
                   $title;
            }
        }
        body {
            a { name is 'top' };
            $code->()
        }
    };
};

private template 'mobile/footer' => sub {
    hr { };
    outs_raw pictogram('8');
    a { attr { 'accesskey' => "8", 'href' => "/mobile/"}
        'back to top'
    }
};

template 'mobile/topics' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            channels     => 1,
        }
    );

    show 'wrapper_mobile', sub {
        for my $channel ( @{ $args{channels} } ) {
            div { attr { class => 'OneTopic' }

                a { attr { href => sprintf('/mobile/channel?channel=%s', $channel->name_urlsafe_encoded) }
                    $channel->name;
                } br { }

                span { $channel->topic } br { }
            }
        }

        show 'footer';
    }, 'topics';
};

template 'mobile/keyword' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            rows         => 1,
            irc_nick     => 1,
        }
    );

    show 'wrapper_mobile', sub {
        a { attr { name => "1" } }
        a { attr { accesskey => '7', href => '#1' } };

        div { attr { class => 'ttlLv1' } 'keyword' };

        for my $row ( @{$args{rows}} ) {
            show '../keyword_line', $row, $args{irc_nick};
        }

        show 'footer';
    }, 'keyword';
};

template 'mobile/top' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            exists_recent_entries => 1,
            keyword_recent_num    => 1,
            channels              => 1,
        }
    );

    show 'wrapper_mobile', sub {
        if ($args{keyword_recent_num} > 0) {
            div {
                class is 'keyword_recent_notice';
                a {
                    href is '/mobile/keyword?recent_mode=on';
                    "Keyword($args{keyword_recent_num})"
                }
            };
        }

        for my $channel (@{$args{channels}}) {
            outs_raw pictogram('(^-^)');
            a {
                href is ('/mobile/channel?channel=' . $channel->name_urlsafe_encoded);
                $channel->name
            };
            if ($channel->unread_lines) {
                a {
                    href is ('/mobile/channel?recent_mode=on&channel=' . $channel->name_urlsafe_encoded);
                    $channel->unread_lines
                }
            }
            br { };
        }
        hr { };
        show 'menu' => (
            exists_recent_entries => $args{exists_recent_entries},
        );
        hr { };
        show '../parts/version_info'
    };
};

template 'mobile/recent' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            channels      => 1,
            has_next_page => 1,
            irc_nick      => 1,
        }
    );

    show 'wrapper_mobile', sub {
        for my $channel ( @{ $args{channels} } ) {
            div {
                class is 'ChannelHeader';
                a {
                    class is 'ChannelName';
                    $channel->name;
                };
                a {
                    href is '/mobile/channel?channel=' . $channel->name_urlsafe_encoded();
                    'more...';
                };
            };

            for my $message (@{$channel->recent_log}) {
                show '../irc_message', $message, $args{irc_nick};
                br { };
            }
            hr {};
        }

        if ($args{has_next_page}) {
            outs_raw pictogram(6);
            a {
                href is '/mobile/recent';
                accesskey is '6';
                'next';
            }
        }

        hr { };

        show 'go_to_top';
    };
};

private template 'mobile/go_to_top' => sub {
    div {
        class is 'GoToTop';
        outs_raw pictogram('8');
        a {
            accesskey is "8";
            href is "/mobile/";
            'ch list'
        };
    };
};

private template 'mobile/menu' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            exists_recent_entries => 1,
        },
    );

    outs_raw pictogram('0');
    a { attr { href => '/mobile/#top', accesskey => 0 }
        'refresh list'
    };
    br { };

    if ($args{exists_recent_entries}) {
        span { '*' }
        a { attr { href => '/mobile/recent', accesskey => '*' }
            'recent'
        }
        br { }
    }
    a { attr { href => '/mobile/topics', accesskey => '#' }
        'topics'
    }
    br { };

    a { attr { 'href' => '/mobile/keyword' }
        'keyword'
    };
    br { };

    outs_raw pictogram('9');
    a {
        attr { href => '/mobile/clear_all_unread', accesskey => '9' }
        'clear_all_unread'
    }
    br { };

};

template 'mobile/channel' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            channel             => 1,
            channel_page_option => 1,
            irc_nick            => 1,
            recent_mode         => 1,
            message             => 1,
        }
    );
    my $channel = $args{channel};

    show 'wrapper_mobile', sub {
        form {
            attr { action => '/mobile/channel?channel=' . $channel->name_urlsafe_encoded, method => 'post' };
            input {
                unless (mobile_agent()->is_non_mobile) {
                    size is 10;
                }
                if ($args{message}) {
                    value is $args{message};
                }
                type is 'text';
                name is 'msg';
            };
            input { attr { type => "submit", accesskey => "1",  value => "OK", } };
        };

        for my $html (@{$args{channel_page_option}}) {
            outs_raw $html;
        }
        br { };

        if ($channel) {
            if (@{$channel->message_log} > 0) {
                if ($args{recent_mode}) {
                    for my $message (reverse $channel->recent_log) {
                        show '../irc_message', $message, $args{irc_nick};
                        br { };
                    }
                    hr { };
                    outs_raw pictogram('5');
                    a {
                        attr { 'accesskey' => 5, href => '/mobile/channel?channel=' . $channel->name_urlsafe_encoded() };
                        'more'
                    };
                } else {
                    for my $message (reverse $channel->message_log) {
                        show '../irc_message', $message, $args{irc_nick};
                        br { };
                    }
                }
            } else {
                p { 'no message here yet' };
            }
        } else {
            p { 'no such channel.' };
        }

        hr { };

        show 'go_to_top';
    }
};

1;
