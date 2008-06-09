package App::Mobirc::Plugin::ChannelPageParts;
use strict;
use MooseX::Plaggerize::Plugin;
use String::TT qw/tt/;

has template => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook channel_page_option => sub {
    my ( $self, $global_context, $channel ) = @_;

    return tt $self->template;
};

1;
