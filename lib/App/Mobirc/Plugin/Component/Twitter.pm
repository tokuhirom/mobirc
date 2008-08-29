package App::Mobirc::Plugin::Component::Twitter;
use strict;
use MooseX::Plaggerize::Plugin;
use POE::Component::Client::Twitter;
use App::Mobirc::Model::Channel;
use App::Mobirc::Util;
use POE;
use POE::Sugar::Args;
use Encode;

has channel => (
    is => 'ro',
    isa => 'Str',
    default => U('#twitter'),
);

has 'alias' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'twitter',
);

has screenname => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { shift->username },
);

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has friend_timeline_interval => (
    is      => 'ro',
    isa     => 'Int',
    default => 60,
);

hook 'process_command' => sub {
    my ($self, $global_context, $command, $channel) = @_;

    if ($self->channel eq $channel->name) {
        $poe_kernel->post( $self->alias, 'update', encode('utf-8', $command) );
        $channel->add_message(
            App::Mobirc::Model::Message->new(
                who   => $self->screenname,
                body  => $command,
                class => 'public',
            )
        );
        return true;
    }
    return false;
};

hook 'run_component' => sub {
    my ( $self, $global_context ) = @_;

    my $twitter = POE::Component::Client::Twitter->spawn( %{ $self } );

    POE::Session->create(
        inline_states => {
            _start => sub {
                my $poe = sweet_args;
                $twitter->yield('register');
                $poe->kernel->delay( 'delay_friend_timeline' => 5);
            },
            delay_friend_timeline => sub {
                my $poe = sweet_args;
                $twitter->yield('friend_timeline');
                $poe->kernel->delay( 'delay_friend_timeline' => $self->friend_timeline_interval );
            },
            'twitter.friend_timeline_success' => sub {
                my $poe = sweet_args;
                my $ret = $poe->args->[0] || [];
                my $channel = $global_context->get_channel( $self->channel );
                DEBUG "twitter friend timeline SUCCESSS!!";
                DEBUG "got lines: " . scalar(@$ret);
                for my $line ( reverse @{$ret} ) {
                    my $who  = U $line->{user}->{screen_name};
                    my $body = U $line->{text};

                    DEBUG "GOT STATUS IS: $body($who)";

                    next if $self->screenname eq $who;

                    $channel->add_message(
                        App::Mobirc::Model::Message->new(
                            who => $who,
                            body => $body,
                            class => 'public',
                        )
                    );
                }
            },
        }
    );
};

no Moose; __PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

App::Mobirc::Plugin::Component::Twitter - twitter component for mobirc

=head1 SYNOPSIS

  - module: App::Mobirc::Plugin::Component::Twitter
    config:
      username: foo
      password: bar
      screenname: bababa
      channel: #mytwitter

