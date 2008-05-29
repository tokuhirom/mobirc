package App::Mobirc::HTTPD::Template::Ajax;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use HTML::Entities qw/encode_entities/;
use App::Mobirc;

private template 'ajax/wrapper_ajax' => sub {
    my ($self, $mobile_agent, $code, $subtitle) = @_;

    xml_decl { 'xml', version => 1.0, encoding => 'UTF-8' };
    html {
        attr { lang => 'ja', 'xml:lang' => 'ja', xmlns => "http://www.w3.org/1999/xhtml" }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=UTF-8" } };
            meta { attr { 'http-equiv' => 'Cache-Control', 'content' => "max-age=0" } };
            meta { attr { name => 'robots', 'content' => 'noindex, nofollow' } };
            link { attr { rel => 'stylesheet', href => '/pc.css', type=> "text/css"} };
            link { attr { rel => 'stylesheet', href => '/mobirc.css', type=> "text/css"} };
            script { src is "/jquery.js" };
            script { src is "/mobirc.js" };
            if ($mobile_agent->user_agent =~ /(?:iPod|iPhone)/) {
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
            $code->()
        }
    }
};

template 'ajax/base' => sub {
    my ($self, $mobile_agent, $docroot) = validate_pos(@_, OBJECT, OBJECT, SCALAR);
    show 'wrapper_ajax', $mobile_agent, sub {
        div {
            id is 'body';
            div {
                id is 'main';
                div { id is 'menu' }
                div { id is 'contents' }
            }
            div {
                id is 'footer';
                form {
                    onsubmit is 'send_message();return false';
                    input { attr { type => 'text', id => 'msg', name => 'msg', size => 30 } };
                    input { attr { type => 'button', value => 'send', onclick => 'send_message();' } };
                }
                div { span { 'mobirc -'} span { class is 'version'; $App::Mobirc::VERSION } };
            }
        };

        script { lang is 'javascript';
            outs_raw qq{docroot = '$docroot';};
        };
    };
};

template 'ajax/menu' => sub {
    my ($self, $server, $keyword_recent_num) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Server' }, SCALAR);

    div {
        show '../keyword_channel', $keyword_recent_num;
        show '../channel_list', $server;
    };
};

private template 'keyword_channel' => sub {
    my ($self, $keyword_recent_num) = validate_pos(@_, OBJECT, SCALAR);

    if ($keyword_recent_num > 0) {
        div { attr { class => 'keyword_recent_notice' }
            a { attr { href => '#' }
                "Keyword($keyword_recent_num)"
            }
        };
    }
};

private template 'channel_list' => sub {
    my ($self, $server) = validate_pos(@_, OBJECT, { 'isa' => 'App::Mobirc::Model::Server' });

    for my $channel ( $server->channels ) {
        my $class = $channel->unread_lines ? 'unread channel' : 'channel';
        div { attr { class => $class }
            a { attr { 'href' => '#' }
                $channel->name
            }
        }
    }
};

template 'ajax/keyword' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            logs     => 1,
            irc_nick => 1,
        },
    );

    div {
        for my $row ( @{ $args{logs} } ) {
            show '../keyword_line', $row, $args{irc_nick};
        }
    }
};

template 'ajax/channel' => sub {
    my ($self, $channel, $irc_nick) = @_;
    div {
        for my $message ($channel->message_log) {
            show '../irc_message', $message, $irc_nick;
            br { };
        }
    }
};

1;
