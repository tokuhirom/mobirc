package App::Mobirc::Web::Template::Root;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';

template 'root/index' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            mobile_agent => 1,
        },
    );

    my $encoding = $args{mobile_agent}->can_display_utf8 ? 'UTF-8' : 'Shift_JIS';
    xml_decl { 'xml', version => '1.0', encoding => $encoding };
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
            title { 'mobirc' }
        }
        body {
            h1 { 'mobirc' };

            div {
                class is 'TopMenu';

                ul {
                    li {
                        a { href is '/mobile/'; 'mobile' };
                    };
                    li {
                        a { href is '/ajax/'; 'ajax' };
                    };
                    li {
                        a { href is '/mobile-ajax/'; 'mobile-ajax' };
                    };
                    li {
                        a { href is '/iphone/'; 'iphone' };
                    };
                };
            };

            hr { };

            div {
                class is 'footer';
                a { attr { href => "http://coderepos.org/share/wiki/mobirc"}; "mobirc" };
            }
        }
    }
};

1;
