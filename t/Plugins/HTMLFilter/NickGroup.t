use strict;
use warnings;
use Test::More tests => 3;
use App::Mobirc;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin(
    {
        module => 'HTMLFilter::NickGroup',
        config => { 'map' => { initialJ => [qw(jknaoya jkondo jagayam)], subtech => [qw/cho45 miyagawa/] } }
    },
);

is get('<span class="nick_normal">(jknaoya)</span>'),
  q{<html><body><span class="nick_initialJ">(jknaoya)</span></body></html>};
is get('<span class="nick_normal">(tokuhirom)</span>'),
  q{<html><body><span class="nick_normal">(tokuhirom)</span></body></html>};
is get('<span class="nick_normal">(miyagawa)</span>'),
  q{<html><body><span class="nick_subtech">(miyagawa)</span></body></html>};

sub get {
    my $nick = shift;
    my ($c, $html) = $mobirc->run_hook_filter('html_filter', undef, $nick);
    $html =~ s/\n$//;
    return $html;
}

