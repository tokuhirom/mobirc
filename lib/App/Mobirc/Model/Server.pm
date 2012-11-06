package App::Mobirc::Model::Server;
use strict;
use warnings;
use Mouse;
use App::Mobirc::Model::Channel;
use Carp;
use App::Mobirc::Util;

has channel_map => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has post_command_cb => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub { sub { die "posting command is not supported by this server" } },
);

has id => (
    is => 'ro',
    required => 1,
);

no Mouse;

sub post_command {
    my ($self, $command, $channel) = @_;
    $self->post_command_cb->($command, $channel);
}

sub add_channel {
    my ($self, $channel) = @_;
    croak "missing channel" unless $channel;
    $channel->server($self);

    $self->channel_map->{$channel->name} = $channel;
}

sub channels {
    my $self = shift;
    my @channels = values %{ $self->channel_map };
    return wantarray ? @channels : \@channels;
}

sub get_channel {
    my ($self, $name) = @_;
    croak "invalid channel name : $name" if $name =~ / /;
    $name = normalize_channel_name($name);
    return $self->channel_map->{$name} ||= App::Mobirc::Model::Channel->new(name=> $name, server => $self);
}

sub delete_channel {
    my ($self, $name) = @_;
    delete $self->channel_map->{$name};
}

sub has_unread_message {
    my $self = shift;
    for my $channel ($self->channels) {
        return 1 if $channel->unread_lines;
    }
    return 0;
}

__PACKAGE__->meta->make_immutable;
