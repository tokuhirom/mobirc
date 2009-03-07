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
            $self->output_body_buffer( $self->output_body_buffer . $buffer );
        },
    }
;

use URI::WithBase;
use IO::Scalar;

sub run {
    my ( $self, $request, %args ) = @_;

    return $self->handle_request(
        uri        => URI::WithBase->new( $request->uri ),
        base       => do {
            my $base = $request->uri->clone;
            $base->path_query('/');
            $base;
        },
        headers    => $request->headers,
        method     => $request->method,
        protocol   => $request->protocol,
        address    => "127.0.0.1",
        port       => "80",
        user       => undef,
        _https_info => undef,
        _connection => {
            input_handle  => IO::Scalar->new( \( $request->content ) ),
            env           => ($args{env} || {}),
        },
        %args,
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

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>
