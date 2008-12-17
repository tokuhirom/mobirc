package App::Mobirc::Model::Message;
use Mouse;
use App::Mobirc::Util;
use HTML::Entities;

has channel => (
    is       => 'rw',
    isa      => 'Any',
);

has who => (
    is  => 'ro',
    isa => 'Str | Undef',
);

has body => (
    is  => 'ro',
    isa => 'Str',
);

has class => (
    is  => 'ro',
    isa => 'Str',
);

has 'time' => (
    is      => 'ro',
    isa     => 'Int',
    default => sub { time() },
);

sub who_class {
    my $self = shift;
    my $who = $self->who;
    if ($who && $who eq irc_nick()) {
        return 'nick_myself';
    } else {
        return 'nick_normal';
    }
}

sub minute {
    my $self = shift;
    my ($sec, $minute, $hour) = localtime($self->time);
    $minute;
}

sub hour {
    my $self = shift;
    my ($sec, $min, $hour) = localtime($self->time);
    $hour;
}

has html_body => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $body = $self->body;
        $body = encode_entities( $body, q{<>&"'} );
        ( $body, ) = global_context->run_hook_filter( 'message_body_filter', $body );
        $body || '';
    }
);

__PACKAGE__->meta->make_immutable;
1;
