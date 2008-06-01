use strict;
use warnings;
use Test::More tests => 3;
use App::Mobirc;

my $mobirc = App::Mobirc->new(
    {
        httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$mobirc->load_plugin(
    {
        module => 'HTMLFilter::NickGroup',
        config => { 'map' => { initialJ => [qw(jknaoya jkondo jagayam)], subtech => [qw/cho45 miyagawa/] } }
    },
);

is get('<a class="nick_normal">jknaoya</a>'), '<a class="nick_initialJ">jknaoya</a>';
is get('<a class="nick_normal">tokuhirom</a>'), q{<a class="nick_normal">tokuhirom</a>};
is get('<a class="nick_normal">miyagawa</a>'), q{<a class="nick_subtech">miyagawa</a>};

sub get {
    my $nick = shift;
    my ($c, $html) = $mobirc->run_hook_filter('html_filter', undef, $nick);
    $html =~ s/\n$//;
    return $html;
}

