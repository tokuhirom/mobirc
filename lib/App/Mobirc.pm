package App::Mobirc;
use Moose;
with 'App::Mobirc::Role::Context', 'MooseX::Plaggerize', 'MooseX::Plaggerize::PluginLoader';
use 5.00800;
use Scalar::Util qw/blessed/;
use POE;
use App::Mobirc::ConfigLoader;
use App::Mobirc::Util;
use App::Mobirc::HTTPD;
use UNIVERSAL::require;
use Carp;
use App::Mobirc::Model::Server;
use Encode;

our $VERSION = '0.99_01';

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
    die "this is instance method" unless blessed $self;

    $self->run_hook('run_component');

    App::Mobirc::HTTPD->init($self->config);

    $poe_kernel->run();
}

1;
__END__

=head1 NAME

App::Mobirc - pluggable IRC to HTTP gateway

=head1 DESCRIPTION

mobirc is a pluggable IRC to HTTP gateway for mobile phones.

=head1 METHODS

=over 4

=item context

get a context object

=item new

create a instance of context object.

=item load_plugins

load plugins

=item config

get a global configuration

=item run

run server

=item register_hook

register hook

=back

=head1 TODO

    use HTTP::MobileAttribute instead of HTTP::MobileAgent

=head1 CODE COVERAGE

I use Devel::Cover to test the code coverage of my tests, below is the Devel::Cover report on this module test suite.

    ---------------------------- ------ ------ ------ ------ ------ ------ ------
    File                           stmt   bran   cond    sub    pod   time  total
    ---------------------------- ------ ------ ------ ------ ------ ------ ------
    blib/lib/App/Mobirc.pm         80.0   35.7   62.5   87.0    0.0    3.0   66.5
    ...lib/App/Mobirc/Channel.pm   77.3   53.6   66.7   81.2   14.3    0.7   68.3
    ...pp/Mobirc/ConfigLoader.pm   94.3   50.0   72.7  100.0    0.0    8.2   81.8
    blib/lib/App/Mobirc/HTTPD.pm   63.3    0.0    0.0   85.2    0.0    1.1   56.4
    ...obirc/HTTPD/Controller.pm   38.9   19.4    0.0   61.3    0.0    1.0   35.6
    ...pp/Mobirc/HTTPD/Router.pm   40.9    0.0    n/a   85.7    0.0    0.1   30.0
    ...lib/App/Mobirc/Message.pm  100.0    n/a    n/a  100.0  100.0    0.3  100.0
    ...n/Authorizer/BasicAuth.pm   48.0    0.0    0.0   57.1    0.0    0.0   38.1
    ...ugin/Authorizer/Cookie.pm   44.7    0.0    0.0   53.8    0.0    0.0   37.8
    ...horizer/EZSubscriberID.pm   48.0    0.0    0.0   57.1    0.0    0.0   40.0
    .../Authorizer/SoftBankID.pm   52.2    0.0    0.0   57.1    0.0    0.0   42.1
    ...in/Component/IRCClient.pm   83.2   33.3   41.7   83.3    0.0    4.7   72.1
    .../Mobirc/Plugin/DocRoot.pm   80.6   25.0    n/a   75.0    0.0   10.0   69.8
    ...PS/InvGeocoder/EkiData.pm   93.8   75.0    n/a  100.0    0.0    1.0   90.9
    ...S/InvGeocoder/Nishioka.pm   96.7   50.0    n/a  100.0    0.0    0.6   92.5
    ...TMLFilter/CompressHTML.pm   90.9    n/a    n/a   80.0    0.0    0.1   85.7
    ...lter/ConvertPictograms.pm   84.6    n/a    n/a   80.0    0.0    0.3   78.9
    ...n/HTMLFilter/DoCoMoCSS.pm  100.0   50.0    n/a  100.0    0.0   65.7   91.2
    ...n/IRCCommand/TiarraLog.pm   21.4    0.0    0.0   57.1    0.0    0.0   18.4
    ...geBodyFilter/Clickable.pm   92.8   83.3   72.7   83.3    0.0    1.3   85.1
    ...ageBodyFilter/IRCColor.pm   87.9   81.0  100.0   81.8    0.0    0.7   83.7
    blib/lib/App/Mobirc/Util.pm   100.0   50.0    n/a  100.0    0.0    1.1   86.3
    Total                          69.6   36.1   36.0   79.2    2.8  100.0   61.8
    ---------------------------- ------ ------ ------ ------ ------ ------ ------

=head1 AUTHOR

Tokuhiro Matsuno and Mobirc AUTHORS.

=head1 LICENSE

GPL 2.0 or later.
