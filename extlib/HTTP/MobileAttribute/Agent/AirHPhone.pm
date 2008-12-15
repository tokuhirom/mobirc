package HTTP::MobileAttribute::Agent::AirHPhone;
use strict;
use warnings;
use HTTP::MobileAttribute::Agent::Base;

__PACKAGE__->mk_accessors(qw/name vendor model model_version browser_version cache_size/);

sub parse {
    my ($self, ) = @_;

    $self->user_agent =~ m!^Mozilla/3\.0\((WILLCOM|DDIPOCKET);(.*)\)! or return $self->no_match;
    $self->{name} = $1;
    @{$self}{qw(vendor model model_version browser_version cache_size)} = split m!/!, $2;
    $self->{cache_size} =~ s/^c//i;
}

1;
