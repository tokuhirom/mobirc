package Mobirc;
use strict;
use warnings;
use Scalar::Util qw/blessed/;
use POE;
use Mobirc::ConfigLoader;
use Mobirc::Util;
use Mobirc::HTTPD;
use Mobirc::IRCClient;

our $VERSION = 0.01;

my $context;
sub context { $context }

sub new {
    my ($class, $config_stuff) = @_;
    my $config = Mobirc::ConfigLoader->load($config_stuff);
    my $self = bless {config => $config}, $class;

    $context = $self;

    return $self;
}

sub config { shift->{config} }

sub run {
    my $self = shift;
    die "this is instance method" unless blessed $self;

    # TODO: pluggable?
    Mobirc::IRCClient->init($self->{config});
    Mobirc::HTTPD->init($self->{config});

    $poe_kernel->run();
}

1;
