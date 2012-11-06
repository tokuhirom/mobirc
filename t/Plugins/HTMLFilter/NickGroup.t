use t::Utils;
use Test::More;
use Test::Requires 'HTML::TreeBuilder::XPath';
plan tests => 3;
use App::Mobirc;

global_context->load_plugin(
    {
        module => 'HTMLFilter::NickGroup',
        config => { 'map' => { initialJ => [qw(jknaoya jkondo jagayam)], subtech => [qw/cho45 miyagawa/] } }
    },
);

is get('<span class="nick_normal">(jknaoya)</span>'),
  q{<span class="nick_initialJ">(jknaoya)</span>};
is get('<span class="nick_normal">(tokuhirom)</span>'),
  q{<span class="nick_normal">(tokuhirom)</span>};
is get('<span class="nick_normal">(miyagawa)</span>'),
  q{<span class="nick_subtech">(miyagawa)</span>};

sub get {
    my $html = shift;
    test_he_filter {
        my $req = shift;
        ($req, $html) = global_context->run_hook_filter('html_filter', $req, $html);
    };
    $html =~ s!^<html><head></head><body>!!;
    $html =~ s!</body></html>$!!;
    $html =~ s/\n$//;
    return $html;
}

