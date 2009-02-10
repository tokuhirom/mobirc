package HTTP::Engine::Middleware::ModuleReload;
use HTTP::Engine::Middleware;
use Module::Reload;

before_handle {
    my ( $c, $self, $req ) = @_;
    Module::Reload->check;
    $req;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::MiddleWare::ModuleReload - module reloader for HTTP::Engine

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(qw/ HTTP::Engine::Middleware::ModuleReload /);
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<Module::Reload>

=cut
