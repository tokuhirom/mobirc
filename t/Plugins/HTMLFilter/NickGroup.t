use t::Utils;
use Test::More;
plan skip_all => 'this test requires XML::LibXML' unless eval 'use XML::LibXML;1;';
plan tests => 3;
use App::Mobirc;

global_context->load_plugin(
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
    my $html = shift;
    test_he_filter {
        my $req = shift;
        ($req, $html) = global_context->run_hook_filter('html_filter', $req, $html);
    };
    $html =~ s/\n$//;
    return $html;
}

