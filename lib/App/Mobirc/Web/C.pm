package App::Mobirc::Web::C;
use strict;
use warnings;
use base qw/Exporter/;
use App::Mobirc::Util;
use App::Mobirc::Web::View;
use App::Mobirc::Web::Template;
use Encode;
use Carp ();
use App::Mobirc::Web::Base;

our @EXPORT = qw/context server render_irc_message render redirect session req param mobile_attribute config/;

sub import {
    my $class = __PACKAGE__;
    my $pkg = caller(0);

    strict->import;
    warnings->import;

    __PACKAGE__->export_to_level(1);
    App::Mobirc::Web::Base->export_to_level(1);
}

*context = *global_context;
sub render_irc_message {
    my $message = shift;
    global_context->mt->render_file(
        "parts/irc_message.mt",
        $message
    )->as_string;
}

sub render {
    my @args = @_;
    my $req = req();

    my $html = sub {
        my $out = App::Mobirc::Web::View->show(@args);
        ($req, $out) = global_context->run_hook_filter('html_filter', $req, $out);
        $out = encode_utf8($out);
    }->();

    Plack::Response->new(
        200,
        ['Content-Type' => _content_type($req)],
        $html,
    );
}

sub _content_type {
    my $req = shift;

    if ( mobile_attribute->is_docomo ) {
        # docomo phone cannot apply css without this content_type
        'application/xhtml+xml; charset=UTF-8';
    }
    else {
        'text/html; charset=UTF-8';
    }
}

# SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
# because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
sub redirect {
    my $path = shift;
    Plack::Response->new(
        302,
        [
            Location => $path
        ],
    );
}

1;
