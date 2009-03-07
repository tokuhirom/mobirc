package HTTP::Engine::Role::ResponseWriter::OutputHeader;
use Any::Moose '::Role';

my $CRLF = "\015\012";

sub output_header {
    my($self, $req, $res) = @_;
    $self->write($self->response_line($res) . $CRLF) if $self->can('response_line');
    $self->write($res->headers->as_string($CRLF));
    $self->write($CRLF);
}

1;

