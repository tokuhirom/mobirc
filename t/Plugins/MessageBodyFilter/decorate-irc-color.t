use strict;
use warnings;
use Data::Dumper;
use App::Mobirc;

use Test::Base;
eval q{ use String::IRC };
plan skip_all => "String::IRC is not installed." if $@;

my $global_context = App::Mobirc->new(
    config => {
        httpd  => { lines => 40 },
        global => { keywords => [qw/foo/] }
    }
);
$global_context->load_plugin( { module => 'MessageBodyFilter::IRCColor', config => { no_decorate => 0} } );

filters {
    input => ['eval', 'decorate_irc_color'],
};

sub decorate_irc_color {
    my $x = shift;
    ($x,) = $global_context->run_hook_filter('message_body_filter', $x);
    return $x;
}

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: <span style="color:yellow;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')
--- expected: <span style="color:red;background-color:green;">world</span>

===
--- input: String::IRC->new('world')->red('green')->bold;
--- expected: <span style="font-weight:bold;color:red;background-color:green;">world</span>

=== inverse is nop.because, html cannot use inverse.
--- input: String::IRC->new('world')->inverse
--- expected: world

===
--- input: String::IRC->new('world')->underline
--- expected: <span style="text-decoration:underline;">world</span>

