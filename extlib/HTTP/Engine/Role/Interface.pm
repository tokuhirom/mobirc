package HTTP::Engine::Role::Interface;
use Any::Moose '::Role';
use HTTP::Engine::Types::Core qw(Handler);
use HTTP::Engine::ResponseFinalizer;

requires 'run';

has request_handler => (
    is       => 'rw',
    isa      => Handler,
    coerce   => 1,
    required => 1,
);

sub handle_request {
    my ($self, %args) = @_;

    my $req = HTTP::Engine::Request->new(
        request_builder => $self->request_builder,
        %args,
    );

    my $res;
    eval {
        $res = $self->request_handler->($req);
        unless ( Scalar::Util::blessed($res)
            && $res->isa('HTTP::Engine::Response') )
        {
            die "You should return instance of HTTP::Engine::Response.";
        }
    };
    if ( my $e = $@ ) {
        print STDERR $e;
        $res = HTTP::Engine::Response->new(
            status => 500,
            body   => 'internal server errror',
        );
    }

    HTTP::Engine::ResponseFinalizer->finalize( $req => $res );

    return $self->response_writer->finalize( $req => $res );
}

1;

__END__

=head1 NAME

HTTP::Engine::Role::Interface - The Interface Role Definition

=head1 SYNOPSIS

  package HTTP::Engine::Interface::CGI;
  use Any::Moose;
  with 'HTTP::Engine::Role::Interface';

=head1 DESCRIPTION

HTTP::Engine::Role::Interface defines the role of an interface in HTTP::Engine.

Specifically, an Interface in HTTP::Engine needs to do at least two things:

=over 4

=item Create a HTTP::Engine::Request object from the client request

If you are on a CGI environment, you need to receive all the data from 
%ENV and such. If you are running on a mod_perl process, you need to muck
with $r. 

In any case, you need to construct a valid HTTP::Engine::Request object
so the application handler can do the real work.

=item Accept a HTTP::Engine::Response object, send it back to the client

The application handler must return an HTTP::Engine::Response object.

In turn, the interface needs to do whatever necessary to present this
object to the client. In a  CGI environment, you would write to STDOUT.
In mod_perl, you need to call the appropriate $r->headers methods and/or
$r->print

=back

=head1 AUTHORS

Kazuhiro Osawa and HTTP::Engine Authors

=head1 SEE ALSO

L<HTTP::Engine>

=cut
