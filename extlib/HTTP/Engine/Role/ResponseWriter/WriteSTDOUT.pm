package HTTP::Engine::Role::ResponseWriter::WriteSTDOUT;
use Any::Moose '::Role';

sub write {
    my($self, $buffer) = @_;
    print STDOUT $buffer;
}

1;
