package HTTP::Engine::Interface::Test;
use HTTP::Engine::Interface
    builder => 'NoEnv',
    writer  => {
        attributes => {
            output_body_buffer => {
                is => 'rw',
            },
        },
        around => {
            finalize => sub {
                my $next = shift;
                my ( $self, $req, $res ) = @_;
                $self->output_body_buffer('');
                $next->(@_);
                $res->body( $self->output_body_buffer );
                $res->as_http_response;
            },
        },
        output_header => sub {},
        write => sub {
            my($self, $buffer) = @_;
            Carp::carp("do not pass the utf8-string as HTTP-Response: '$buffer'") if Encode::is_utf8($buffer);
            $self->output_body_buffer( $self->output_body_buffer . $buffer );
        },
    }
;

use HTTP::Engine::Test::Request;
use Carp ();
use Encode ();

sub run {
    my ( $self, $request, %args ) = @_;
    Carp::croak('missing request object') unless $request;
    Carp::croak('incorrect request object($request->uri() returns undef)') unless $request->uri;
    if ($request->method eq 'POST') {
        Carp::carp('missing content-length header') unless defined $request->content_length;
        Carp::carp('missing content-type header') unless $request->content_type;
    }

    return $self->handle_request(
        HTTP::Engine::Test::Request->build_request_args(
            $request->uri,
            $request->content,
            {
                headers  => $request->headers,
                method   => $request->method,
                protocol => $request->protocol,
                %args,
            },
        ),
    );
}

__INTERFACE__

__END__

=encoding utf8

=head1 NAME

HTTP::Engine::Interface::Test - HTTP::Engine Test Interface

=head1 SYNOPSIS

  use Data::Dumper;
  use HTTP::Engine;
  use HTTP::Request;
  my $response = HTTP::Engine->new(
      interface => {
          module => 'Test',
          request_handler => sub {
              my $req = shift;
              HTTP::Engine::Response->new( body => Dumper($req) );
          }
      },
  )->run(HTTP::Request->new( GET => 'http://localhost/' ), env => \%ENV);
  print $response->content;

=head1 DESCRIPTION

HTTP::Engine::Interface::Test is test engine base class

=head1 SEE ALSO

L<HTTP::Engine::Test::Request>

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>
