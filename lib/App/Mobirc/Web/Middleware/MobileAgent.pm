package App::Mobirc::Web::Middleware::MobileAgent;
use strict;
use warnings;
use HTTP::Engine::Request;
use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Charset;

sub import {
    *HTTP::Engine::Request::mobile_agent = sub {
        my $self = shift;
        $self->{mobile_agent} ||= HTTP::MobileAgent->new( $self->headers );
    };
}

1;
