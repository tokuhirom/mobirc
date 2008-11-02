package App::Mobirc::Web::Template::Account;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use HTML::Entities qw/encode_entities/;
use App::Mobirc;

template 'account/wrapper' => sub {
    my ($self, $mobile_agent, $code) = @_;
    my $encoding = $mobile_agent->can_display_utf8 ? 'UTF-8' : 'Shift_JIS';
    xml_decl { 'xml', version => '1.0', encoding => $encoding };
    outs_raw qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};
    html { attr { 'lang' => 'ja', 'xml:lang' => 'ja', xmlns => 'http://www.w3.org/1999/xhtml' }
        head {
            meta { attr { 'http-equiv' => 'Content-Type', 'content' => "text/html; charset=$encoding" } }
            meta { attr { 'http-equiv' => 'Cache-Control', content => 'max-age=0' } }
            meta { attr { name => 'robots', content => 'noindex, nofollow' } }
            link { attr { rel => 'stylesheet', href => '/static/mobirc.css', type=> "text/css"} };
            link { attr { rel => 'stylesheet', href => '/static/mobile.css', type=> "text/css"} };
            title { 'account' };
        }
        body {
            $code->()
        }
    };
};

template 'account/login' => sub {
    my $self = shift;
    my %args = validate(
        @_ => {
            mobile_agent => 1,
            req => 1,
        }
    );

    show 'wrapper', $args{mobile_agent}, sub {
        for my $key (qw/password cidr mobileid/) {
            if ($args{req}->params->{"invalid_${key}"}) {
                div { attr { style => 'color: red' }, "invalid $key" };
            }
        }
        h1 { 'login with mobile id' };
        form {
            attr { action => '/account/login_mobileid', method => 'post' };
            input { attr { type => 'submit', value => 'login' } };
        };

        h1 { 'login with password' };
        form {
            attr { action => '/account/login_password', method => 'post' };
            input { attr { type => 'password', name => 'password' } };
            input { attr { type => 'submit', value => 'login' } };
        };
    };
};

1;

