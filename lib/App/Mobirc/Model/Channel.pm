package App::Mobirc::Model::Channel;
use Moose;
use Scalar::Util qw/blessed/;
use Carp;
use List::MoreUtils qw/any all/;
use App::Mobirc::Util;
use App::Mobirc::Model::Message;
use MIME::Base64::URLSafe;
use Encode;

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

has topic => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has global_context => (
    is      => 'rw',
    isa     => 'App::Mobirc',
    default => sub { App::Mobirc->context },
);

has name => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

around 'new' => sub {
    my ($next, $class, $trash, $name) = @_;
    $next->($class, name => $name);
};

sub add_message {
    my ($self, $message) = @_;

    unless ($self->name eq '*keyword*') {
        $message->channel($self);
        Scalar::Util::weaken($message->{channel});
    }

    # update log
    $self->_add_to_log(message_log => $message);
    $self->_add_to_log(recent_log  => $message);

    # update keyword buffer.
    if ($message->class eq 'public' && $self->name ne '*keyword*') {
        if ((any { $message->body =~ /$_/i } @{$self->{global_context}->config->{global}->{keywords} || []})
         && (all { $message->body !~ /$_/i } @{$self->{global_context}->config->{global}->{stopwords} || ["\0"]})) {
            App::Mobirc::Model::Channel->update_keyword_buffer($self->{global_context}, $message);
        }
    }
}

sub _add_to_log {
    my ($self, $key, $row) = @_;

    my $log_max = $self->{global_context}->config->{httpd}->{lines} || 20;

    push @{$self->{$key}}, $row;
    if ( @{$self->{$key}} > $log_max ) {
        shift @{$self->{$key}}; # trash old one.
    }
}

sub update_keyword_buffer {
    my ($class, $global_context, $message) = @_;
    croak "this is class method" if blessed $class;
    croak "global context required" unless blessed $global_context;

    DEBUG "UPDATE KEYWORD: $message";
    $global_context->get_channel(U '*keyword*')->add_message( $message );
}

sub unread_lines {
    my $self = shift;

    return
      scalar grep { $_->class eq "public" || $_->class eq "notice" }
      @{ $self->{recent_log} };
}

sub clear_unread {
    my $self = shift;

    $self->{recent_log} = [];
}

sub post_command {
    my ($self, $command) = @_;

    $self->{global_context}->run_hook_first('process_command', $command, $self);
}

sub recent_log_count {
    my $self = shift;
    scalar @{ $self->recent_log };
}

sub name_urlsafe_encoded {
    my $self = shift;
    urlsafe_b64encode(encode_utf8 $self->name);
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

