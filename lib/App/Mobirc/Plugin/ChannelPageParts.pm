package App::Mobirc::Plugin::ChannelPageParts;
use strict;
use App::Mobirc::Plugin;
use Text::MicroTemplate qw/render_mt/;

has template => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

hook channel_page_option => sub {
    my ( $self, $global_context, $channel ) = @_;

    return render_mt($self->template, {channel => $channel})->as_string;
};

1;
