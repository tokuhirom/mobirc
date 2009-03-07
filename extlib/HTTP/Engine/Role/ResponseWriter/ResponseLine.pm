package HTTP::Engine::Role::ResponseWriter::ResponseLine;
use Any::Moose '::Role';
use HTTP::Status ();

sub response_line {
    my ($self, $res) = @_;

    join(" ", $res->protocol, $res->status, HTTP::Status::status_message($res->status));
}

1;
