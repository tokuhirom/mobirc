use strict;
use warnings;
use Test::More tests => 2;
use App::Mobirc;
use App::Mobirc::Plugin::Authorizer::BasicAuth;
use MIME::Base64 ();
use t::Utils;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin( {module => 'Authorizer::BasicAuth', config => {username => 'dankogai', password => 'kogaidan'}} );

test_he_filter {
    my $req = shift;

    my $set = sub {
        my ($user, $passwd) = @_;
        $req->header('Authorization' => 'Basic ' . MIME::Base64::encode("$user:$passwd", ''));
        $req;
    };
    ok !$mobirc->run_hook_first('authorize', $set->('dankogai', 'dankogai'));
    ok $mobirc->run_hook_first('authorize', $set->('dankogai', 'kogaidan'));
};

