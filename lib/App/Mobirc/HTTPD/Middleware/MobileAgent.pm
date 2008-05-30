package App::Mobirc::HTTPD::Middleware::MobileAgent;
use Moose;

sub setup {
    my $meta = HTTP::Engine::Request->meta;
    $meta->make_mutable;
    $meta->add_attribute(
        mobile_agent => (
            is      => 'ro',
            isa     => 'Object',
            lazy    => 1,
            default => sub {
                my $self = shift;
                HTTP::MobileAgent->new( $self->headers );
            },
        )
    );
    $meta->make_immutable;
}

1;
