package t::Utils;
use strict;
use warnings;
use lib 'extlib';
use Test::More;
use HTTP::Request;
use App::Mobirc;
use App::Mobirc::Web::Handler;
use App::Mobirc::Web::Template;
use HTTP::Session;
use HTTP::Session::Store::OnMemory;
use HTTP::Session::State::Null;
use App::Mobirc::Util;
use Cwd;
use HTTP::Message::PSGI;
use Plack::Request;
use Plack::Response;

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
    my $c = App::Mobirc->new(
        config => {
            httpd  => { lines => 40 },
            global => {
                keywords => [qw/foo/],
                stopwords => [qw/foo31/],
                assets_dir => File::Spec->catfile(Cwd::cwd(), 'assets'),
            },
            plugin => [
                +{
                    "module" => "Component::IRCClient",
                    "config" => {
                        "host"=>"127.0.0.1",
                        "port"=>"6667",
                        "nick"=>"john1",
                        "desc"=>"john-freenode1",
                        "username"=>"john-freenode1",
                        "password"=>"pa55w0rd",
                        "incode"=>"utf-8",
                        "id"=>"f1",
                        "ssl"=> 1,
                    },
                }
            ],
        }
    );
    return $c;
}

sub test_he {
    my ($req, $cb) = @_;
    $req or die "missing request";
    if ($req->isa('HTTP::Request')) {
        $req = Plack::Request->new(req_to_psgi($req));
    }

    my $app = sub {
        local $App::Mobirc::Web::Handler::CONTEXT = App::Mobirc::Web::Context->new(
            req     => $req,
            session => HTTP::Session->new(
                store   => HTTP::Session::Store::OnMemory->new(),
                state   => HTTP::Session::State::Null->new(),
                request => $req,
            ),
        );
        $cb->($req),
    };
    return $app->();
}

sub test_he_filter(&) {
    my $cb = shift;

    global_context();

    test_he( HTTP::Request->new('GET', '/', ['User-Agent' => 'MYPC']), sub {
        my $req = shift;
        $cb->($req);
        return Plack::Response->new( 200 );
    });
}

sub server () {
    my $c = global_context;
    unless (@{$c->irc_components}) {
        $c->run_hook('run_component');
    }
    $c->servers->[0];
}

{
    no warnings 'redefine';
    *App::Mobirc::Web::Template::Run::irc_nick = sub () { 'tokuhirom' };
    *App::Mobirc::Model::Message::irc_nick = sub () { 'tokuhirom' };
    *App::Mobirc::current_nick = sub { 'tokuhirom' };
}

sub keyword_channel () { global_context->keyword_channel() }

sub test_channel    () { server->get_channel(U '#test') }

sub describe ($&) {
    my ($name, $code) = @_;

    subtest $name => sub {
        $code->();
        keyword_channel->clear_unread();
        done_testing();
    };
}

sub test_view {
    my ($path, @args) = @_;
    my $res;
    test_he_filter {
        $res = global_context->mt->render_file(
            $path,
            @args,
        )->as_string;
    };
    $res;
}

create_global_context();
global_context->run_hook('run_component');

1;
