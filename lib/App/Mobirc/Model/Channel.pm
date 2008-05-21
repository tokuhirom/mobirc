package App::Mobirc::Model::Channel;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;
use Scalar::Util qw/blessed/;
use Carp;
use List::MoreUtils qw/any all/;
use App::Mobirc::Util;

__PACKAGE__->mk_accessors(qw/message_log recent_log topic/);

sub new {
    my ($class, $global_context, $name) = @_;
    croak "global context missing" unless blessed $global_context && $global_context->isa("App::Mobirc");
    croak "missing channel name" unless defined $name;
    croak "Invalid channel name $name" if $name =~ / /;
    bless {global_context => $global_context, name => $name, message_log => [], recent_log => []}, $class;
}

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

    my $log_max = $self->{global_context}->config->{httpd}->{lines};

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

    for my $code (@{$self->{global_context}->get_hook_codes('process_command')}) {
        my $ret = $code->($self->{global_context}, $command, $self);
        last if $ret;
    }
}

sub name {
    my ($self, $name) = @_;

    if (@_ == 1) {
        return $self->{name};
    } else {
        croak "channel name is flagged utf8" unless Encode::is_utf8($name);
        $self->{name} = $name;
    }
}

1;
__END__

=head1 NAME

App::Mobirc::Model::Channel - channel object for mobirc

=head1 DESCRIPTION

INTERNAL USE ONLY

=head1 SEE ALSO

L<App::Mobirc>

