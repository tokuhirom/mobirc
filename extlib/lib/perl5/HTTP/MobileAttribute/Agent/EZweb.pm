package HTTP::MobileAttribute::Agent::EZweb;
use strict;
use warnings;
use HTTP::MobileAttribute::Agent::Base;

__PACKAGE__->mk_accessors(qw/name version model device_id server comment/);

sub parse {
    my ( $self, ) = @_;

    my $ua = $self->user_agent;
    if ( $ua =~ s/^KDDI\-// ) {
        # KDDI-TS21 UP.Browser/6.0.2.276 (GUI) MMP/1.1
        my ( $device, $browser, $opt, $server ) = split / /, $ua, 4;
        $self->{device_id} = $device;

        my ( $name, $version ) = split m!/!, $browser;
        $self->{name}    = $name;
        $self->{version} = "$version $opt";
        $self->{server}  = $server;
    }
    else {
        # UP.Browser/3.01-HI01 UP.Link/3.4.5.2
        my ( $browser, $server, $selfomment ) = split / /, $ua, 3;
        my ( $name, $software ) = split m!/!, $browser;
        $self->{name} = $name;
        @{$self}{qw(version device_id)} = split /-/, $software;
        $self->{server} = $server;
        if ($selfomment) {
            $selfomment =~ s/^\((.*)\)$/$1/;
            $self->{comment} = $selfomment;
        }
    }
    $self->{model} = $self->{device_id};
}


1;
