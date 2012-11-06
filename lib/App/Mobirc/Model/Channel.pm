package App::Mobirc::Model::Channel;
use strict;
use warnings;
use Mouse;
use Scalar::Util qw/blessed/;
use Carp;
use List::MoreUtils qw/any all uniq/;
use App::Mobirc::Util;
use App::Mobirc::Model::Message;
use MIME::Base64::URLSafe;
use Encode;
use Tatsumaki::MessageQueue;

has server => (
    is => 'rw',
    isa => 'Maybe[App::Mobirc::Model::Server]',
    required => 1,
    weak_ref => 1,
);

has message_log => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { +[] },
    auto_deref => 1,
);

has recent_log => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { +[] },
    auto_deref => 1,
);

has members => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { +[] },
    auto_deref => 1,
);

has topic => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has name => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

# last updated time
has mtime => (
    is => 'rw',
    isa => 'Int',
    default => sub { 0 },
);

sub join_member {
    my ($self, $nick) = @_;
    push @{$self->members}, $nick;
    $self->members([uniq @{$self->members}]);
}

sub part_member {
    my ($self, $nick) = @_;
    $self->members( [ grep { $_ ne $nick } $self->members ] );
}

sub add_message {
    my $self = shift;
    my $message = @_ == 1 ? $_[0] : App::Mobirc::Model::Message->new(@_);

    unless ($self->name eq '*keyword*') {
        $message->channel($self);
        Scalar::Util::weaken($message->{channel});
    }

    # update log
    $self->_add_to_log(message_log => $message);
    $self->_add_to_log(recent_log  => $message);

    # update keyword buffer.
    if ($message->class eq 'public' && $self->name ne '*keyword*') {
        if ((any { $message->body =~ /$_/i } @{global_context->config->{global}->{keywords} || []})
         && (all { $message->body !~ /$_/i } @{global_context->config->{global}->{stopwords} || ["\0"]})) {
            App::Mobirc::Model::Channel->update_keyword_buffer($message);
        }
        $self->mtime(time());
    }

    # send to tatsumaki queue
    Tatsumaki::MessageQueue->instance('mobirc')->publish(
        {
            %{ $message->as_hashref },
            type         => 'message',
            is_keyword   => $self->name eq '*keyword*' ? 1 : 0,
        }
    );
}

sub _add_to_log {
    my ($self, $key, $row) = @_;

    my $log_max = global_context->config->{global}->{log_max} || 20;

    push @{$self->{$key}}, $row;
    if ( @{$self->{$key}} > $log_max ) {
        shift @{$self->{$key}}; # trash old one.
    }
}

sub update_keyword_buffer {
    my ($class, $message) = @_;
    croak "this is class method" if blessed $class;

    DEBUG "UPDATE KEYWORD: $message";
    global_context->keyword_channel()->add_message( $message );
}

sub unread_lines {
    my $self = shift;

    return
      scalar grep { ($_->class eq "public" || $_->class eq "notice") && ($_->who ne 'tiarra') }
      @{ $self->{recent_log} };
}

sub clear_unread {
    my $self = shift;

    $self->{recent_log} = [];
}

sub post_command {
    my ($self, $command) = @_;
    $self->server->post_command($command, $self);
}

sub recent_log_count {
    my $self = shift;
    scalar @{ $self->recent_log };
}

sub name_urlsafe_encoded {
    my $self = shift;
    urlsafe_b64encode(encode_utf8 $self->name);
}

sub fullname {
    my $self = shift;
    my $name = $self->name;
    if (0+@{global_context->servers} > 1 && $self->server) {
        $name .= "@" . $self->server->id;
    }
    return $name;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

App::Mobirc::Model::Channel - channel object for mobirc

=head1 DESCRIPTION

INTERNAL USE ONLY

=head1 SEE ALSO

L<App::Mobirc>

