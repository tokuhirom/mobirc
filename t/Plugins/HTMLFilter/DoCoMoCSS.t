use strict;
use warnings;
use Test::More tests => 3;
use HTTP::MobileAgent;
use App::Mobirc;
use App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS;

my $global_context = App::Mobirc->new(
    {
        httpd  => { port     => 3333, title => 'mobirc', lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
App::Mobirc::Plugin::HTMLFilter::DoCoMoCSS->register(
    $global_context
);
is scalar(@{$global_context->get_hook_codes('html_filter')}), 1;
my $code = $global_context->get_hook_codes('html_filter')->[0];
is ref($code), 'CODE';

my $src = <<'...';
<style type="text/css">
    a {
        color: red;
    }
</style>
<a href="/">foo</a>
...

my $dst = <<'...';
<?xml version="1.0"?>
<a href="/" style="color:red;">foo</a>
...

is $code->({mobile_agent => HTTP::MobileAgent->new('DoCoMo/2.0 P2101V(c100)')}, $src), $dst;

