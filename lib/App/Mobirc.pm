package App::Mobirc;
use strict;
use warnings;
use Mouse;
with 'App::Mobirc::Role::Plaggable';
use 5.01000;
use Scalar::Util qw/blessed/;
use AnyEvent;
use App::Mobirc::Util;
use UNIVERSAL::require;
use Carp;
use App::Mobirc::Model::Server;
use App::Mobirc::Model::Channel;
use Encode;
use App::Mobirc::Types 'Config';
use Text::MicroTemplate::File;
use App::Mobirc::Web::Template;

our $VERSION = '4.05';

has keyword_channel => (
    is => 'rw',
    default => sub {
        App::Mobirc::Model::Channel->new(name => '*keyword*', server => undef)
    },
);

has irc_components => (
    is      => 'rw',
    isa     => 'ArrayRef[App::Mobirc::Plugin::Component::IRCClient]',
    default => sub { +[ ] },
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

    my @plugins;
    for my $plugin (@{ $self->config->{plugin} }) {
        $plugin->{module} =~ s/^App::Mobirc::Plugin:://;
        my $plugin = $self->load_plugin( $plugin );
        push @plugins, $plugin;
    }

    # check the server id's unique
    my %uniq;
    for my $plugin (@plugins) {
        if ($plugin->isa('App::Mobirc::Plugin::Component::IRCClient')) {
            next if $uniq{$plugin->id}++ == 0;
            die "[FATAL] Duplicated server id: " . $plugin->id;
        }
    }
}

sub run {
    my $self = shift;
    croak "this is instance method" unless blessed $self;

    $self->run_hook('run_component');

    $SIG{INT} = sub { die "SIGINT\n" };

    AE::cv->recv;
}

sub is_my_nick {
    my ($self, $who) = @_; $who // die;
    for my $nick (map { $_->current_nick } @{$self->irc_components}) {
        if ($nick && $who eq $nick) {
            return 1;
        }
    }
    return 0;
}

sub channels {
    my $self = shift;
    my @channels = map { @{$_->server->channels} }
                    @{$self->irc_components};
    wantarray ? @channels : \@channels;
}

sub unread_channels {
    my $self = shift;
    my @channels = grep { $_->unread_lines } $self->channels;
    wantarray ? @channels : \@channels;
}

sub servers {
    my $self = shift;
    my @servers = map { $_->server } @{$self->irc_components};
    wantarray ? @servers : \@servers;
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

sub has_unread_message {
    my $self = shift;
    for my $server (map { $_->server } @{$self->irc_components}) {
        return 1 if $server->has_unread_message;
    }
    return 0;
}

sub get_server {
    my ($self, $server_id) = @_; $server_id // die "Missing args";
    for my $server (map { $_->server } @{$self->irc_components}) {
        if ($server->id eq $server_id) {
            return $server;
        }
    }
    return undef;
}

no Mouse; __PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

App::Mobirc - pluggable IRC to HTTP gateway

=head1 DESCRIPTION

mobirc is a pluggable IRC to HTTP gateway.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

and Mobirc AUTHORS.

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
