package App::Mobirc;
use Mouse;
with 'App::Mobirc::Role::Plaggable';
use 5.00800;
use Scalar::Util qw/blessed/;
use POE;
use App::Mobirc::Util;
use UNIVERSAL::require;
use Carp;
use App::Mobirc::Model::Server;
use Encode;
use App::Mobirc::Types 'Config';
use Text::MicroTemplate::File;
use App::Mobirc::Web::Template;

our $VERSION = '2.00';

has server => (
    is      => 'ro',
    isa     => 'App::Mobirc::Model::Server',
    default => sub { App::Mobirc::Model::Server->new() },
    handles => [qw/add_channel delete_channel channels get_channel delete_channel/], # for backward compatibility
);

has config => (
    is       => 'ro',
    isa      => Config,
    required => 1,
    coerce   => 1,
);

has mt => (
    is => 'ro',
    isa => 'Text::MicroTemplate::File',
    lazy => 1,
    default => sub {
        my $self = shift;
        Text::MicroTemplate::File->new(
            include_path => [ File::Spec->catdir($self->config->{global}->{assets_dir}, 'tmpl') ],
            package_name => "App::Mobirc::Web::Template",
            use_cache    => 1,
        );
    },
);

{
    my $context;
    sub context { $context }
    sub _set_context { $context = $_[1] }
}

sub BUILD {
    my ($self, ) = @_;
    $self->_load_plugins();
    $self->_set_context($self);
}

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

no Mouse; __PACKAGE__->meta->make_immutable;
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
