package App::Mobirc::Web::Template::Ajax;
use App::Mobirc::Web::Template;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use HTML::Entities qw/encode_entities/;
use App::Mobirc;

template 'ajax/base' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            user_agent => 1,
            docroot    => 1,
        },
    );

    xml_decl { 'xml', version => '1.0', encoding => 'UTF-8' };
    outs_raw qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};
    html {
        attr { lang => 'ja', 'xml:lang' => 'ja', xmlns => "http://www.w3.org/1999/xhtml" }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=UTF-8" } };
            meta { attr { 'http-equiv' => 'Cache-Control', 'content' => "max-age=0" } };
            meta { attr { name => 'robots', 'content' => 'noindex, nofollow' } };
            link { attr { rel => 'stylesheet', href => '/static/pc.css', type=> "text/css"} };
            link { attr { rel => 'stylesheet', href => '/static/mobirc.css', type=> "text/css"} };
            script { src is "/static/jquery.js" };
            script { src is "/static/mobirc.js" };
            if ($args{user_agent} =~ /(?:iPod|iPhone)/) {
                meta { attr { name => 'viewport', content => 'width=device-width' } }
                meta { attr { name => 'viewport', content => 'initial-scale=1.0, user-scalable=yes' } }
            }
            title { 'mobirc' }
        }
        body {
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

            # TODO: move this part to Plugin::DocRoot
            script { lang is 'javascript';
                outs_raw qq{docroot = '$args{docroot}';};
            };
        }
    }
};

template 'ajax/menu' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            server             => { isa => 'App::Mobirc::Model::Server' },
            keyword_recent_num => SCALAR,
        },
    );

    div {
        show '../keyword_channel', $args{keyword_recent_num};
        show '../channel_list', $args{server};
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
        },
    );

    div {
        for my $row ( @{ $args{logs} } ) {
            show '../keyword_line', $row;
        }
    }
};

template 'ajax/channel' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            channel  => 1,
        },
    );
    div {
        for my $message ($args{channel}->message_log) {
            outs_raw(render_irc_message($message)->as_string);
            br { };
        }
    }
};

1;
