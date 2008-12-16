package App::Mobirc::Web::Middleware::MobileAgent;
use strict;
use warnings;
use HTTP::Engine::Request;
use HTTP::MobileAgent;

BEGIN {
    ## no critic.
    sub HTTP::MobileAgent::can_display_utf8 {
        my $self = shift;
        return 1;
    }

    ## no critic.
    sub HTTP::MobileAgent::encoding {
        my $self = shift;
        'utf-8'
    }

    *HTTP::Engine::Request::mobile_agent = sub {
        my $self = shift;
        $self->{mobile_agent} ||= HTTP::MobileAgent->new( $self->headers );
    };
}

1;
