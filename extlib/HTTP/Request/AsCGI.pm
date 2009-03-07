package HTTP::Request::AsCGI;

use strict;
use warnings;
use bytes;
use base 'Class::Accessor::Fast';

use Carp;
use HTTP::Response;
use IO::Handle;
use IO::File;

__PACKAGE__->mk_accessors(qw[ enviroment request stdin stdout stderr ]);

our $VERSION = 0.5;

sub new {
    my $class   = shift;
    my $request = shift;

    unless ( @_ % 2 == 0 && eval { $request->isa('HTTP::Request') } ) {
        croak(qq/usage: $class->new( \$request [, key => value] )/);
    }

    my $self = $class->SUPER::new( { restored => 0, setuped => 0 } );
    $self->request($request);
    $self->stdin( IO::File->new_tmpfile );
    $self->stdout( IO::File->new_tmpfile );

    my $host = $request->header('Host');
    my $uri  = $request->uri->clone;
    $uri->scheme('http')    unless $uri->scheme;
    $uri->host('localhost') unless $uri->host;
    $uri->port(80)          unless $uri->port;
    $uri->host_port($host)  unless !$host || ( $host eq $uri->host_port );

    $uri = $uri->canonical;

    my $enviroment = {
        GATEWAY_INTERFACE => 'CGI/1.1',
        HTTP_HOST         => $uri->host_port,
        HTTPS             => ( $uri->scheme eq 'https' ) ? 'ON' : 'OFF',  # not in RFC 3875
        PATH_INFO         => $uri->path,
        QUERY_STRING      => $uri->query || '',
        SCRIPT_NAME       => '/',
        SERVER_NAME       => $uri->host,
        SERVER_PORT       => $uri->port,
        SERVER_PROTOCOL   => $request->protocol || 'HTTP/1.1',
        SERVER_SOFTWARE   => "HTTP-Request-AsCGI/$VERSION",
        REMOTE_ADDR       => '127.0.0.1',
        REMOTE_HOST       => 'localhost',
        REMOTE_PORT       => int( rand(64000) + 1000 ),                   # not in RFC 3875
        REQUEST_URI       => $uri->path_query,                            # not in RFC 3875
        REQUEST_METHOD    => $request->method,
        @_
    };

    foreach my $field ( $request->headers->header_field_names ) {

        my $key = uc("HTTP_$field");
        $key =~ tr/-/_/;
        $key =~ s/^HTTP_// if $field =~ /^Content-(Length|Type)$/;

        unless ( exists $enviroment->{$key} ) {
            $enviroment->{$key} = $request->headers->header($field);
        }
    }

    unless ( $enviroment->{SCRIPT_NAME} eq '/' && $enviroment->{PATH_INFO} ) {
        $enviroment->{PATH_INFO} =~ s/^\Q$enviroment->{SCRIPT_NAME}\E/\//;
        $enviroment->{PATH_INFO} =~ s/^\/+/\//;
    }

    $self->enviroment($enviroment);

    return $self;
}

sub setup {
    my $self = shift;

    $self->{restore}->{enviroment} = {%ENV};

    binmode( $self->stdin );

    if ( $self->request->content_length ) {

        syswrite( $self->stdin, $self->request->content )
          or croak("Can't write request content to stdin handle: $!");

        sysseek( $self->stdin, 0, SEEK_SET )
          or croak("Can't seek stdin handle: $!");
    }

    open( $self->{restore}->{stdin}, '<&', STDIN->fileno )
      or croak("Can't dup stdin: $!");

    open( STDIN, '<&=', $self->stdin->fileno )
      or croak("Can't open stdin: $!");

    binmode( STDIN );

    if ( $self->stdout ) {

        open( $self->{restore}->{stdout}, '>&', STDOUT->fileno )
          or croak("Can't dup stdout: $!");

        open( STDOUT, '>&=', $self->stdout->fileno )
          or croak("Can't open stdout: $!");

        binmode( $self->stdout );
        binmode( STDOUT);
    }

    if ( $self->stderr ) {

        open( $self->{restore}->{stderr}, '>&', STDERR->fileno )
          or croak("Can't dup stderr: $!");

        open( STDERR, '>&=', $self->stderr->fileno )
          or croak("Can't open stderr: $!");

        binmode( $self->stderr );
        binmode( STDERR );
    }

    {
        no warnings 'uninitialized';
        %ENV = %{ $self->enviroment };
    }

    if ( $INC{'CGI.pm'} ) {
        CGI::initialize_globals();
    }

    $self->{setuped}++;

    return $self;
}

sub response {
    my ( $self, $callback ) = @_;

    return undef unless $self->stdout;

    seek( $self->stdout, 0, SEEK_SET )
      or croak("Can't seek stdout handle: $!");

    my $headers;
    while ( my $line = $self->stdout->getline ) {
        $headers .= $line;
        last if $headers =~ /\x0d?\x0a\x0d?\x0a$/;
    }
    
    unless ( defined $headers ) {
        $headers = "HTTP/1.1 500 Internal Server Error\x0d\x0a";
    }

    unless ( $headers =~ /^HTTP/ ) {
        $headers = "HTTP/1.1 200 OK\x0d\x0a" . $headers;
    }

    my $response = HTTP::Response->parse($headers);
    $response->date( time() ) unless $response->date;

    my $message = $response->message;
    my $status  = $response->header('Status');

    if ( $message && $message =~ /^(.+)\x0d$/ ) {
        $response->message($1);
    }

    if ( $status && $status =~ /^(\d\d\d)\s?(.+)?$/ ) {

        my $code    = $1;
        my $message = $2 || HTTP::Status::status_message($code);

        $response->code($code);
        $response->message($message);
    }
    
    my $length = ( stat( $self->stdout ) )[7] - tell( $self->stdout );

    if ( $response->code == 500 && !$length ) {

        $response->content( $response->error_as_HTML );
        $response->content_type('text/html');

        return $response;
    }

    if ($callback) {

        my $handle = $self->stdout;

        $response->content( sub {

            if ( $handle->read( my $buffer, 4096 ) ) {
                return $buffer;
            }

            return undef;
        });
    }
    else {

        my $length = 0;

        while ( $self->stdout->read( my $buffer, 4096 ) ) {
            $length += length($buffer);
            $response->add_content($buffer);
        }

        if ( $length && !$response->content_length ) {
            $response->content_length($length);
        }
    }

    return $response;
}

sub restore {
    my $self = shift;

    {
        no warnings 'uninitialized';
        %ENV = %{ $self->{restore}->{enviroment} };
    }

    open( STDIN, '<&', $self->{restore}->{stdin} )
      or croak("Can't restore stdin: $!");

    sysseek( $self->stdin, 0, SEEK_SET )
      or croak("Can't seek stdin: $!");

    if ( $self->{restore}->{stdout} ) {

        STDOUT->flush
          or croak("Can't flush stdout: $!");

        open( STDOUT, '>&', $self->{restore}->{stdout} )
          or croak("Can't restore stdout: $!");

        sysseek( $self->stdout, 0, SEEK_SET )
          or croak("Can't seek stdout: $!");
    }

    if ( $self->{restore}->{stderr} ) {

        STDERR->flush
          or croak("Can't flush stderr: $!");

        open( STDERR, '>&', $self->{restore}->{stderr} )
          or croak("Can't restore stderr: $!");

        sysseek( $self->stderr, 0, SEEK_SET )
          or croak("Can't seek stderr: $!");
    }

    $self->{restored}++;

    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->restore if $self->{setuped} && !$self->{restored};
}

1;

__END__

=head1 NAME

HTTP::Request::AsCGI - Setup a CGI enviroment from a HTTP::Request

=head1 SYNOPSIS

    use CGI;
    use HTTP::Request;
    use HTTP::Request::AsCGI;
    
    my $request = HTTP::Request->new( GET => 'http://www.host.com/' );
    my $stdout;
    
    {
        my $c = HTTP::Request::AsCGI->new($request)->setup;
        my $q = CGI->new;
        
        print $q->header,
              $q->start_html('Hello World'),
              $q->h1('Hello World'),
              $q->end_html;
        
        $stdout = $c->stdout;
        
        # enviroment and descriptors will automatically be restored 
        # when $c is destructed.
    }
    
    while ( my $line = $stdout->getline ) {
        print $line;
    }
    
=head1 DESCRIPTION

Provides a convinient way of setting up an CGI enviroment from a HTTP::Request.

=head1 METHODS

=over 4 

=item new ( $request [, key => value ] )

Contructor, first argument must be a instance of HTTP::Request
followed by optional pairs of environment key and value.

=item enviroment

Returns a hashref containing the environment that will be used in setup. 
Changing the hashref after setup has been called will have no effect.

=item setup

Setups the environment and descriptors.

=item restore

Restores the enviroment and descriptors. Can only be called after setup.

=item request

Returns the request given to constructor.

=item response

Returns a HTTP::Response. Can only be called after restore.

=item stdin

Accessor for handle that will be used for STDIN, must be a real seekable
handle with an file descriptor. Defaults to a tempoary IO::File instance.

=item stdout

Accessor for handle that will be used for STDOUT, must be a real seekable
handle with an file descriptor. Defaults to a tempoary IO::File instance.

=item stderr

Accessor for handle that will be used for STDERR, must be a real seekable
handle with an file descriptor.

=back

=head1 SEE ALSO

=over 4

=item examples directory in this distribution.

=item L<WWW::Mechanize::CGI>

=item L<Test::WWW::Mechanize::CGI>

=back

=head1 THANKS TO

Thomas L. Shinnick for his valuable win32 testing.

=head1 AUTHOR

Christian Hansen, C<ch@ngmedia.com>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut
