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

sub import {
    my $pkg = caller(0);
    my $class = shift;

    strict->import;
    warnings->import;

    {
        no strict 'refs';
        for my $meth (qw/test_he test_he_filter create_global_context global_context server hack_irc_nick/) {
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
                assets_dir => 'assets',
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

sub global_context () {
    unless (App::Mobirc->context) {
        create_global_context();
    }
    App::Mobirc->context
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

sub hack_irc_nick {
    my ($nick, $code) = @_;
    no warnings 'redefine';
    local *App::Mobirc::Web::Template::IRCMessage::irc_nick = sub () { $nick };
    $code->();
}

1;
