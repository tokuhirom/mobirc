package HTTP::Engine::Middleware::FillInForm;
use HTTP::Engine::Middleware;
use HTML::FillInForm;

has 'autorun_on_post' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

middleware_method 'HTTP::Engine::Response::fillin_form' => sub {
    my ($self, $fdat) = @_;
    $self->{__PACKAGE__ . '::flag'}++;
    $self->{__PACKAGE__ . '::fdat'} = $fdat;
    return $self; # I love method chain
};

after_handle {
    my ( $c, $self, $req, $res ) = @_;

    if ($res->{__PACKAGE__ . '::flag'} || ($self->autorun_on_post && $req->method eq 'POST')) {
        my $fdat = $res->{__PACKAGE__ . '::fdat'} || $req;
        my $body = HTML::FillInForm->fill(\( $res->body ), $fdat);
        $res->body($body);
    }

    $res;
};

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::FillInForm - fill-in-form stuff

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;

    $mw->install('HTTP::Engine::Middleware::FillInForm');
    # or
    $mw->install(
        'HTTP::Engine::Middleware::FillInForm' => {
            autorun_on_post => 1
        }
    );

    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler(
                sub {
                    HTTP::Engine::Response->new(
                        body => '<form><input type="text" name="foo" /></form>'
                    )->fillin_form()  # when no args, fill-in-form from request params.
                    # or
                    HTTP::Engine::Response->new(
                        body => '<form><input type="text" name="foo" /></form>'
                    )->fillin_form({'foo' => 'bar'})
                }
            ),
        }
    )->run();

=head1 AUTHORS

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTML::FillInForm>

