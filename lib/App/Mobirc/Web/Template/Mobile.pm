package App::Mobirc::Web::Template::Mobile;
use App::Mobirc::Web::Template;
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

sub _footer {
    my $pict = pictogram('8');
    <<"...";
<hr />
$pict <a href="/mobile/" accesskey="8">back to top</a>
...
}

sub topics {
    my $class = shift;
    my %args = validate(
        @_ => {
            channels     => 1,
        }
    );
    mt_cached_with_wrap(<<'...', $args{channels});
? my $channels = shift;
? for my $channel (@{$channels}) {
    <div class="OneTopic">
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a><br />
        <span><?= $channel->topic ?></span><br />
    </div>
? }
...
}

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

sub top {
    my $self = shift;
    my %args = validate(
        @_ => {
            exists_recent_entries => 1,
            keyword_recent_num    => 1,
            channels              => 1,
        }
    );

    mt_cached_with_wrap(<<'...', $args{exists_recent_entries}, $args{keyword_recent_num}, $args{channels});
? my ($exists_recent_entries, $keyword_recent_num, $channels) = @_

? if ($keyword_recent_num) {
    <div class="keyword_recent_notice">
        <a href="/mobile/keyword?recent_mode=on">Keyword(<?= $keyword_recent_num ?>)</a>
    </div>
? }

? for my $channel (@$channels) {
    <?= pictogram('(^-^)') ?>
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a>
    <? if ($channel->unread_lines) { ?>
        <a href="/mobile/channel?recent_mode=on&channel=<?= $channel->name_urlsafe_encoded ?>">
            <?= $channel->unread_lines ?>
        </a>
    <? }                             ?>
    <br />
? }

<hr />

<?= pictogram('0') ?><a href="/mobile/#top" accesskey="0">refresh list</a><br />
? if ($exists_recent_entries) {
    <span>*</span><a href="/mobile/recent" accesskey="*">recent</a><br />
? }
<? # TODO: use pictogram for '#' & '*' ?>
<span>#</span><a href="/mobile/topics" accesskey="#">topics</a><br />
<span>!</span><a href="/mobile/keyword" accesskey="!">keyword</a><br />
<span><?= pictogram('9') ?></span><a href="/mobile/clear_all_unread" accesskey="9">clear_all_unread</a><br />

<hr />

App::Mobirc <?= $App::Mobirc::VERSION ?>
...
}

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
