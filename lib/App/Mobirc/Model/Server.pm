package App::Mobirc::Model::Server;
use strict;
use Moose;
use App::Mobirc::Model::Channel;
use Carp;
use App::Mobirc::Util;

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

# shortcut
sub keyword_channel {
    my $self = shift;
    $self->get_channel(U '*keyword*');
}

# ORDER BY unread_lines, last_updated_at;
sub channels_sorted {
    my $self = shift;

    my $channels = [
        reverse
          map {
              $_->[0];
          }
          sort {
              $a->[1] <=> $b->[1] ||
              $a->[2] <=> $b->[2]
          }
          map {
              my $unl  = $_->unread_lines ? 1 : 0;
              my $buf  = $_->message_log || [];
              my $last =
                (grep {
                    $_->{class} eq "public" ||
                    $_->{class} eq "notice"
                } @{ $buf })[-1] || {};
              my $time = ($last->{time} || 0);
              [$_, $unl, $time];
          }
          $self->channels
    ];
    wantarray ? @$channels : $channels;
}

__PACKAGE__->meta->make_immutable;
1;
