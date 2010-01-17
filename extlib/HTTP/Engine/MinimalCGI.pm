package HTTP::Engine::MinimalCGI;
use strict;
use warnings;
use Scalar::Util                    ();
use HTTP::Headers::Fast             ();
use HTTP::Engine::ResponseFinalizer ();
use CGI::Simple                     ();

my $CRLF = "\015\012";

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub run {
    my ($self, ) = @_;

    ### run handler
    my $req = HTTP::Engine::Request->new();
    my $res = $self->{request_handler}->( $req );
    unless ( Scalar::Util::blessed($res) && $res->isa('HTTP::Engine::Response') ) {
        die "You should return instance of HTTP::Engine::Response.";
    }
    HTTP::Engine::ResponseFinalizer->finalize($req => $res);
    print join(
        '',
        $res->headers->as_string_without_sort($CRLF),
        $CRLF,
        $res->body
    );
}

{
    package # hide from pause
        HTTP::Engine;

    sub new {
        my ($class, %args) = @_;
        unless (Scalar::Util::blessed($args{interface})) {
            if ($args{interface}->{module} ne 'MinimalCGI') {
                die "MinimalCGI is the only interface supported. Use the real HTTP::Engine for others.";
            }
            $args{interface} = HTTP::Engine::MinimalCGI->new(
                request_handler => $args{interface}->{request_handler}
            );
        }
        bless { interface => $args{interface} }, $class;
    }

    sub run { $_[0]->{interface}->run() }
}


{
    package # hide from pause
        HTTP::Engine::Response;

    sub new {
        my ($class, %args) = @_;
        bless {
            status  => 200,
            body    => '',
            headers => HTTP::Headers::Fast->new(),
            %args,
        }, $class;
    }
    sub header {
        my $self = shift;
        $self->{headers}->header(@_);
    }
    sub headers {
        my $self = shift;
        $self->{headers};
    }
    sub status {
        my $self = shift;
        $self->{status} = shift if @_;
        $self->{status};
    }
    sub body {
        my $self = shift;
        $self->{body} = shift if @_;
        $self->{body};
    }
    sub protocol       { 'HTTP/1.0' };
    sub content_length { my $self = shift; $self->{headers}->content_length(@_) };
    sub content_type   { my $self = shift; $self->{headers}->content_type(@_) };
    sub cookies        {
        my $self = shift;
        $self->{cookies} ||= do {
            if (my $header = $self->header('Cookie')) {
                +{ CGI::Simple::Cookie->parse($header) };
            } else {
                +{};
            }
        }
    }
}

{
    package # hide from pause
        HTTP::Engine::Request;

    sub new {
        my ($class, ) = @_;
        bless { }, $class;
    }

    sub hostname { $ENV{HTTP_HOST} || $ENV{SERVER_HOST} }
    sub protocol { $ENV{SERVER_PROTOCOL} || 'HTTP/1.0' }
    sub method   { $ENV{REQUEST_METHOD} || 'GET' }

    sub param {
        my $self = shift;
        $self->{cs} ||= CGI::Simple->new();
        $self->{cs}->param(@_);
    }
    sub upload {
        my $self = shift;
        $self->{cs} ||= CGI::Simple->new();
        $self->{cs}->upload(@_);
    }
    sub header {
        my ($self, $key) = @_;
        $key = uc $key;
        $key =~ s/-/_/;
        $ENV{'HTTP_' . $key} || $ENV{'HTTPS_' . $key};
    }
}

1;

__END__

=head1 NAME

HTTP::Engine::MinimalCGI - fast loading, minimal HTTP::Engine::Interface

=head1 SYNOPSIS

    use HTTP::Engine::MinimalCGI;

    my $engine = HTTP::Engine->new(
        interface => {
            module => 'MinimalCGI',
            request_handler => sub {
                my $req = shift;
                HTTP::Engine::Response->new(
                    status => 200,
                    body   => 'Hello, world!',
                );
            },
        },
    );
    $engine->run;

=head1 DESCRIPTION

HTTP::Engine::MinimalCGI implements a minimal version of the HTTP::Engine spec
for the vanilla CGI environment. It has a very fast compile time-- on par with
CGI::Simple or CGI.pm-- and is forward-compatible with the full HTTP::Engine
spec. However, it is missing some features.

=head1 SUPPORTED METHODS

    Request
        new
        hostname
        protocol
        method
        param
        upload

    Response
        new
        header
        headers
        status
        body
        protocol
        content_length
        content_type
        cookies

=head1 WHY DO WE NEED THIS?

Some people says "HTTP::Engine is too heavy on my shared hosting account".
Perhaps you believe that professional web developers don't use vanilla CGI.
But newbies and small projects use shared hosting accounts and will find the
performance of this solution in vanilla CGI is sufficient. 

=head1 WARNINGS

B<DO NOT LOAD FULL SPEC HTTP::Engine AND THIS MODULE IN ONE PROCESS>.  HTTP::Engine::MinimalCGI
provides alternative, conflicting implementations of the L<HTTP::Engine>,
L<HTTP::Engine::Request>, L<HTTP::Engine::Response> namespaces.


=head1 DEPENDENCIES

L<CGI::Simple>, L<HTTP::Headers::Fast>, L<Scalar::Util>

=head1 AUTHORS

tokuhirom

=head1 CONTRIBUTORS

Mark Stosberg <mark@summersault.com> - helped with the documentation.

