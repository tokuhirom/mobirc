package App::Mobirc::HTTPD::Template::IRCMessage;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use List::Util qw/first/;
use HTML::Entities qw/encode_entities/;

template 'irc_message' => sub {
    my ($self, $message, $my_nick) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Message' }, SCALAR);

    show '_irc_time', $message->time;
    if ($message->who) {
        show '_irc_who',  $message->who, $my_nick;
    }
    show '_irc_body', $message->class, $message->body;
};

# render time likes: 12:25
template '_irc_time' => sub {
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

template '_irc_who' => sub {
    my ( $self, $who, $my_nick ) = validate_pos( @_, OBJECT, SCALAR, SCALAR );

    my $who_class = do {
        # this part is hacked by hirose31.
        # TODO: This config should not be in IRCClient's config.
        # TODO: shouldn't this feature be in core? Plugin::NickGroup?
        my %groups = do {
            require App::Mobirc;
            my $g = {};
            for my $p ( @{ App::Mobirc->context->config->{plugin} || [] } ) {
                if ( $p->{module} eq 'App::Mobirc::Plugin::Component::IRCClient' ) {
                    $g = $p->{config}->{groups} if exists $p->{config}->{groups};
                    last;
                }
            }
            %$g;
        };

        ### fixme store this hash to context and reuse it?
        my %class_for;    # nick -> who_class ("nick_" + groupname)
        while ( my ( $group, $nicks ) = each %groups ) {
            for my $nick ( @{$nicks} ) {
                push @{ $class_for{$nick} }, "nick_" . $group;
            }
        }

        if ( $who eq $my_nick ) {
            'nick_myself';
        }
        elsif ( my $nick = first { $who =~ /^$_/i } keys %class_for ) {
            join( ' ', @{ $class_for{$nick} } );
        }
        else {
            'nick_normal';
        }
    };

    span { attr { class => $who_class };
        "($who)"
    };
};

template '_irc_body' => sub {
    my ( $self, $class, $body ) = validate_pos( @_, OBJECT, SCALAR, SCALAR );

    my $c = App::Mobirc->context;
    my $codes = $c->get_hook_codes('message_body_filter') || [];

    $body = encode_entities($body);
    for my $filter ( @{ $codes } ) {
        $body = $filter->($body);
    }

    span { attr { class => $class }
        outs_raw $body
    };
};

1;
