package App::Mobirc::Web::Template::IRCMessage;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use List::Util qw/first/;
use HTML::Entities qw/encode_entities/;
use App::Mobirc::Web::View;
use App::Mobirc::Util qw/irc_nick/;

template 'irc_message' => sub {
    my ($self, $message, ) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Message' });

    # i want to strip spaces. cellphone hates spaces.
    my $html = App::Mobirc::Web::View->show( '_irc_message', $message);
    $html =~ s/^\s+//smg;
    $html =~ s/\n//g;
    outs_raw $html;
};

template '_irc_message' => sub {
    my ($self, $message) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Message' });

    show 'irc_time', $message->time;
    if ($message->who) {
        show 'irc_who',  $message->who;
    }
    show 'irc_body', $message->class, $message->body;
};

# render time likes: 12:25
private template 'irc_time' => sub {
    my ( $self, $time ) = validate_pos( @_, OBJECT, SCALAR );
    my ( $sec, $min, $hour ) = localtime($time);
    span {
        attr { class => 'time' };
        span { attr { class => 'hour' };
            sprintf '%02d', $hour
        };
        span { attr { class => 'colon' };
            ':'
        };
        span { attr { class => 'minute' };
            sprintf '%02d', $min
        };
    };
};

private template 'irc_who' => sub {
    my ( $self, $who, ) = validate_pos( @_, OBJECT, SCALAR );

    my $who_class = ( $who eq irc_nick() ) ?  'nick_myself' : 'nick_normal';

    span { attr { class => $who_class };
        "($who)"
    };
};

private template 'irc_body' => sub {
    my ( $self, $class, $body ) = validate_pos( @_, OBJECT, SCALAR, SCALAR );

    $body = encode_entities($body, q{<>&"'});
    ($body, ) = App::Mobirc->context->run_hook_filter('message_body_filter', $body);

    span { attr { class => $class }
        outs_raw $body
    };
};

1;
