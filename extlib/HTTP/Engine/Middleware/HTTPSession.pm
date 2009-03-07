package HTTP::Engine::Middleware::HTTPSession;
use HTTP::Engine::Middleware;
use Scalar::Util qw/blessed/;
use Any::Moose 'X::Types' => [ -declare => [qw/State Store/] ];
use HTTP::Session;

subtype State,
    as 'CodeRef';
coerce State,
    from 'Object',
        via {
            my $x = $_;
            sub { $x }
        };
coerce State,
    from 'HashRef',
        via {
            my $klass = $_->{class};
            $klass = $klass =~ s/^\+// ? $klass : "HTTP::Session::State::${klass}";
            Any::Moose::load_class($klass);
            my $obj = $klass->new( $_->{args} );
            sub { $obj };
        };

subtype Store,
    as 'CodeRef';
coerce Store,
    from 'Object',
        via {
            my $x = $_;
            sub { $x }
        };
coerce Store,
    from 'HashRef',
        via {
            my $klass = $_->{class};
            $klass = $klass =~ s/^\+// ? $klass : "HTTP::Session::Store::${klass}";
            Any::Moose::load_class($klass);
            my $obj = $klass->new( $_->{args} );
            sub { $obj };
        };

has 'state' => (
    is     => 'ro',
    isa    => State,
    coerce => 1,
);

has 'store' => (
    is     => 'ro',
    isa    => Store,
    coerce => 1,
);

{
    my $SESSION;
    my $SELF;
    my $REQ;

    middleware_method 'session' => sub {
        $SESSION ||= HTTP::Session->new(
            state   => $SELF->state->(),
            store   => $SELF->store->(),
            request => $REQ,
        );
    };

    before_handle {
        (undef, $SELF, $REQ) = @_;
        undef $SESSION;
        $REQ;
    };

    after_handle {
        my ($c, $self, $req, $res) = @_;
        if ($SESSION) {
            $SESSION->response_filter($res);
            $SESSION->finalize();
        }
        undef $SESSION;
        undef $SELF;
        undef $REQ;
        $res;
    };
}

__MIDDLEWARE__

__END__

=head1 NAME

HTTP::Engine::Middleware::HTTPSession - session support at middleware layer

=head1 SYNOPSIS

    my $mw = HTTP::Engine::Middleware->new;
    $mw->install( 'HTTP::Engine::Middleware::HTTPSession' => {
        state => {
            class => 'URI',
            args  => {
                session_id_name => 'foo_sid',
            },
        },
        store => {
            class => 'Test',
            args => { },
        },
    });
    HTTP::Engine->new(
        interface => {
            module => 'YourFavoriteInterfaceHere',
            request_handler => $mw->handler( \&handler ),
        }
    )->run();

=head1 DESCRIPTION

This middleware add the session management stuff for your web application

=head1 AUTHOR

tokuhirom

=head1 SEE ALSO

L<HTTP::Engine::Middleware>, L<HTTP::Session>

