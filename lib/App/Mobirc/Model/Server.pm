package App::Mobirc::Model::Server;
use strict;
use MooseX::Singleton;
use App::Mobirc::Model::Channel;
use Carp;

has channel_map => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

sub add_channel {
    my ($self, $channel) = @_;
    croak "missing channel" unless $channel;

    $self->channel_map->{$channel->name} = $channel;
}

sub channels {
    my $self = shift;
    my @channels = values %{ $self->channel_map };
    return wantarray ? @channels : \@channels;
}

sub get_channel {
    my ($self, $name) = @_;
    croak "channel name is flagged utf8" unless Encode::is_utf8($name);
    croak "invalid channel name : $name" if $name =~ / /;
    return $self->channel_map->{$name} ||= App::Mobirc::Model::Channel->new($self, $name);
}

sub delete_channel {
    my ($self, $name) = @_;
    croak "channel name is flagged utf8" unless Encode::is_utf8($name);
    delete $self->channel_map->{$name};
}

1;
