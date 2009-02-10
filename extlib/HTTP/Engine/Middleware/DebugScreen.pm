package HTTP::Engine::Middleware::DebugScreen;
use HTTP::Engine::Middleware;

use HTTP::Engine::Response;

use Scope::Upper qw( localize_elem :words );

has 'powerd_by' => (
    is      => 'rw',
    default => __PACKAGE__,
);

has 'renderer' => (
    is => 'rw',
);

has 'err_info' => (
    is => 'rw',
);

has 'response' => (
    is => 'rw',
);

has 'stacktrace_required' => (
    is  => 'rw',
    isa => 'Bool',
);


before_handle {
    my($c, $self, $req) = @_;

    $self->response(undef);
    $self->err_info(undef);
    $self->stacktrace_required(0);

    localize_elem '%SIG', '__DIE__' => sub { $c->diecatch(1); died($self, @_) } => SUB UP;

    $req;
};

after_handle {
    my($c, $self, $req, $res) = @_;

    if ($self->err_info) {
        $res = HTTP::Engine::Response->new;
        $res->code(500);
        $res->body(
            $self->err_info->as_html(
                powered_by => $self->powerd_by,
                ($self->renderer ? (renderer => $self->renderer) : ())
            )
        );
    }

    $res;
};

sub detach { die bless [@_], 'CGI::ExceptionManager::Exception' }

sub died {
    my($self, $msg) = @_;

    if (ref $msg eq 'CGI::ExceptionManager::Exception') {
        $self->response($msg->[0]);
        $self->err_info(undef);
    } else {
        unless ($self->stacktrace_required) {
            require CGI::ExceptionManager::StackTrace;
            $self->stacktrace_required(1);
        }
        $self->err_info( CGI::ExceptionManager::StackTrace->new($msg) );
    }
    die $msg;
}

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::DebugScreen - documentation is TODO

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install(qw/ HTTP::Engine::Middleware::DebugScreen /);
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 SEE ALSO

L<Scope::Upper>, L<CGI::ExceptionManager::StackTrace>

=cut
