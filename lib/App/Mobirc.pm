package App::Mobirc;
use Moose;
with 'App::Mobirc::Role::Context', 'MooseX::Plaggerize';
use 5.00800;
use Scalar::Util qw/blessed/;
use POE;
use App::Mobirc::ConfigLoader;
use App::Mobirc::Util;
use UNIVERSAL::require;
use Carp;
use App::Mobirc::Model::Server;
use Encode;

our $VERSION = '1.00';

has server => (
    is      => 'ro',
    isa     => 'App::Mobirc::Model::Server',
    default => sub { App::Mobirc::Model::Server->new() },
    handles => [qw/add_channel delete_channel channels get_channel delete_channel/], # for backward compatibility
);

has config => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

around 'new' => sub {
    my ($next, $class, $config_stuff) = @_;
    my $config = App::Mobirc::ConfigLoader->load($config_stuff); # TODO: use coercing

    my $self = $next->( $class, config => $config );

    $self->_load_plugins();

    return $self;
};

sub _load_plugins {
    my $self = shift;
    for my $plugin (@{ $self->config->{plugin} }) {
        $plugin->{module} =~ s/^App::Mobirc::Plugin:://;
        $self->load_plugin( $plugin );
    }
}

sub run {
    my $self = shift;
    croak "this is instance method" unless blessed $self;

    $self->run_hook('run_component');

    # POE::Sugar::Args => Devel::Caller::Perl => DB => DB::catch(do not catch here)
    $SIG{INT} = sub { die "SIGINT\n" };

    $poe_kernel->run();
}

1;
__END__

=head1 NAME

App::Mobirc - pluggable IRC to HTTP gateway

=head1 DESCRIPTION

mobirc is a pluggable IRC to HTTP gateway.

=head1 AUTHOR

Tokuhiro Matsuno and Mobirc AUTHORS.

=head1 LICENSE

GPL 2.0 or later.
