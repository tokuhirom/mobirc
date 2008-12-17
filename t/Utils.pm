package t::Utils;
use strict;
use warnings;
use lib 'extlib';
use HTTP::Engine;
use HTTP::Request;
use App::Mobirc;
use App::Mobirc::Web::Handler;
use App::Mobirc::Web::Template;
use HTTP::Session;
use HTTP::Session::Store::OnMemory;
use HTTP::Session::State::Null;
use App::Mobirc::Util;
use Cwd;

sub import {
    my $pkg = caller(0);
    my $class = shift;

    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/test_he test_he_filter create_global_context global_context server describe keyword_channel test_channel test_view/) {
            *{"${pkg}::${meth}"} = *{"${class}::${meth}"};
        }
    }
}

sub create_global_context {
    App::Mobirc->new(
        config => {
            httpd  => { lines => 40 },
            global => {
                keywords => [qw/foo/], stopwords => [qw/foo31/],
                assets_dir => File::Spec->catfile(Cwd::cwd(), 'assets'),
            }
        }
    );
}

sub test_he {
    my ($req, $cb) = @_;

    HTTP::Engine->new(
        interface => {
            module          => 'Test',
            request_handler => sub {
                my $req = shift;
                local $App::Mobirc::Web::Handler::CONTEXT = App::Mobirc::Web::Context->new(
                    req     => $req,
                    session => HTTP::Session->new(
                        store   => HTTP::Session::Store::OnMemory->new(),
                        state   => HTTP::Session::State::Null->new(),
                        request => $req,
                    ),
                  );
                $cb->($req),
            }
        }
    )->run( $req );
}

sub test_he_filter(&) {
    my $cb = shift;

    global_context();

    test_he( HTTP::Request->new('GET', '/', ['User-Agent' => 'MYPC']), sub {
        my $req = shift;
        $cb->($req);
        return HTTP::Engine::Response->new( status => 200 );
    });
}

sub server () {
    global_context->server
}

{
    no warnings 'redefine';
    *App::Mobirc::Web::Template::Run::irc_nick = sub () { 'tokuhirom' };
    *App::Mobirc::Model::Message::irc_nick = sub () { 'tokuhirom' };
    *App::Mobirc::Util::irc_nick = sub () { 'tokuhirom' };
}

sub keyword_channel () { server->get_channel(U "*keyword*") }

sub test_channel    () { server->get_channel(U '#test') }

sub describe ($&) {
    my ($name, $code) = @_;

    $code->();
    keyword_channel->clear_unread();
}

sub test_view {
    my ($path, @args) = @_;
    my $res;
    test_he_filter {
        my $mt = global_context->mt;

        local $App::Mobirc::Template::REQUIRE_WRAP;
        $res = $mt->render_file(
            $path,
            @args,
        );
        if ($App::Mobirc::Template::REQUIRE_WRAP) {
            $res = $mt->render_file(
                File::Spec->catfile('parts/wrapper.mt'),
                $res,
            );
        } else {
            $res;
        }
    };
    $res->as_string;
}

create_global_context();

1;
