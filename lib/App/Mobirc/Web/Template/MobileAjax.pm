package App::Mobirc::Web::Template::MobileAjax;
use App::Mobirc::Web::Template
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use App::Mobirc;
use Path::Class;

private template 'mobile-ajax/wrapper_mobile' => sub {
    my ($self, $code) = @_;
    my $encoding = 'UTF-8';

    xml_decl { 'xml', version => '1.0', encoding => $encoding };
    outs_raw qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};
    html { attr { 'lang' => 'ja', 'xml:lang' => 'ja', xmlns => 'http://www.w3.org/1999/xhtml' }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=$encoding" } }
            meta { attr { 'http-equiv' => 'Cache-Control', content => 'max-age=0' } }
            meta { attr { 'http-equiv' => "content-script-type", content => "text/javascript" } };
            meta { attr { name => 'robots', content => 'noindex, nofollow' } }
            link { attr { rel => 'stylesheet', href => '/static/mobirc.css', type=> "text/css"} };
            link { attr { rel => 'stylesheet', href => '/static/mobile-ajax.css', type=> "text/css"} };
            if (mobile_agent()->user_agent =~ /(?:iPod|iPhone)/) {
                meta { attr { name => 'viewport', content => 'width=device-width' } }
                meta { attr { name => 'viewport', content => 'initial-scale=1.0, user-scalable=yes' } }
            }
            title { "mobirc" }
            style {
                type is 'text/css';
                outs_raw load_assets('static', 'mobile-ajax.css');
            };
        }
        body {
            $code->()
        }
    };
};

template 'mobile-ajax/index' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            channels     => 1,
            docroot      => 1,
        },
    );

    show 'wrapper_mobile', sub {
        textarea {
            id is 'stylesheet';
            style is 'display: none';
            outs load_assets('static', 'mobile-ajax.css');
        };
        h1 {
            select {
                attr { id => 'channel', onchange => "Mobirc.onChangeChannel();" };
                for my $channel ( @{$args{channels}} ) {
                    option {
                        value is $channel->name;
                        $channel->name;
                    };
                }
            };
        };

        div {
            id is "channel-iframe-container";
            class is "iframe-container";
            outs_raw '&nbsp;';
        };

        form {
            onsubmit is 'return Mobirc.onSubmit()';
            action is '/mobirc-ajax/channel';
            method is 'post';

            if (mobile_agent()->user_agent =~ /(?:iPod|iPhone)/) {
                input {
                    type is 'text';
                    id is 'msg';
                    name is 'msg';
                };
            } else {
                input {
                    type is 'text';
                    id is 'msg';
                    name is 'msg';
                    size is '30';
                };
            }

            input { attr { type => 'submit', accesskey => '1', value => 'OK[1]' } };
        };

        div { attr { id => "recentlog-iframe-container", class => "iframe-container" } };

        p { attr { style => "border-top: 1px solid black" }
            outs '# ';
            a { attr { href => "/mobile/topics", accesskey => "#" };
                'topics' };
            outs ' | ';
            a { attr { href => "/mobile/keyword" }
                'keyword'
            }
        };

        div {
            class is 'VersionInfo';
            outs 'mobirc - ';
            span { attr { class => "version"}
                $App::Mobirc::VERSION
            }
        };

        div {
            id is "jsonp-container";
        };

        div {
            id is "submit-iframe-container";
            style is "_isplay:none;";
        };

        # TODO: move this part to Plugin::DocRoot
        script { lang is 'javascript';
            outs_raw qq{___docroot = '$args{docroot}';};
        };

        outs_raw qq{<script type="text/javascript">\n};
        outs_raw load_assets('static', 'mobile-ajax.js');
        outs_raw qq{\n</script>\n};
    };
};

sub load_assets {
    my @path = @_;
    my $config = App::Mobirc->context->config;
    file($config->{global}->{assets_dir}, @path)->slurp;
}

1;
