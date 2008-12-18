package App::Mobirc::Plugin::ChannelPageParts;
use strict;
use App::Mobirc::Plugin;
use Text::MicroTemplate qw/build_mt/;

has template => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has template_compiled => (
    is => 'ro',
    isa => 'CodeRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        build_mt(template => $self->template, package_name => 'App::Mobirc::Web::Template');
    },
);

hook channel_page_option => sub {
    my ( $self, $global_context, $channel ) = @_;

    return $self->template_compiled->($channel);
};

1;
