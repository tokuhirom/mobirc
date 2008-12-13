package HTTP::Engine::Role::ResponseWriter::WriteSTDOUT;
use Mouse::Role;

sub write {
    my($self, $buffer) = @_;
    print STDOUT $buffer;
}

1;
