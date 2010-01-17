package HTTP::Engine::Interface::ServerSimple;
use Any::Moose;
use HTTP::Engine::Interface
    builder => 'NoEnv',
    writer  => {
        response_line => 1,
    }
;

use HTTP::Server::Simple 0.34;
use HTTP::Server::Simple::CGI;

has host => (
    is      => 'ro',
    isa     => 'Str',
    default => '127.0.0.1',
);

has port => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has net_server => (
    is      => 'ro',
    isa     => 'Str | Undef',
    default => undef,
);

has net_server_configure => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

has print_banner => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
    default  => sub { sub {
        my $self = shift;
        print(  __PACKAGE__
              . " : You can connect to your server at "
              . "http://" . ($self->host || 'localhost') . ":"
              . $self->port
              . "/\n" );
    } }
);

sub run {
    my ($self, ) = @_;

    my $headers;
    my %setup;
    my $server;
    $server = any_moose('::Meta::Class')
        ->create_anon_class(
            superclasses => ['HTTP::Server::Simple'],
            methods => {
                setup => sub {
                    shift; # $self;
                    $headers = HTTP::Headers::Fast->new;
                    %setup = @_;
                },
                headers => sub {
                    my ( $self, $args ) = @_;
                    $headers->header(@$args) if @$args;
                },
                handler    => sub {
                    my($host, $port) = $headers->header('Host') ?
                        split(':', $headers->header('Host')) :($setup{localname}, $setup{localport});
                    my $base = "http://${host}";
                    $base .= ":$port" if $port;
                    my $request_uri = $setup{request_uri};
                    $request_uri = '/' if $request_uri =~ m!^https?://!i;
                    my $uri = URI::WithBase->new(
                        $base . $request_uri,
                        $base . '/',
                    );
                    $self->handle_request(
                        uri => $uri,
                        connection_info => {
                            method      => $setup{method},
                            protocol    => $setup{protocol},
                            address     => $setup{peeraddr},
                            port        => $setup{localport},
                            user        => undef,
                            _https_info => undef,
                            request_uri => $setup{request_uri},
                        },
                        headers     => $headers,
                        _connection => {
                            env           => {},
                            input_handle  => \*STDIN,
                            output_handle => \*STDOUT,
                        },
                    )
                },
                net_server => sub { $self->net_server },
                print_banner => sub { $self->print_banner->($self) },
            },
            cache => 1
        )->name->new(
            $self->port
        );
    $server->host($self->host);
    $server->run(%{ $self->net_server_configure });
}

__INTERFACE__

__END__

=head1 NAME

HTTP::Engine::Interface::ServerSimple - HTTP::Server::Simple interface for HTTP::Engine

=head1 DESCRIPTION

HTTP::Engine::Plugin::Interface::ServerSimple is wrapper for HTTP::Server::Simple.

HTTP::Server::Simple is flexible web server.And it can use Net::Server, so you can make it preforking or using Coro.

=head1 ATTRIBUTES

=over 4

=item host

=item port

=item net_server

User-overridable method. If you set it to a L<Net::Server> subclass, that subclass is used for the L<HTTP::Server::Simple>.

=item net_server_configure

Any arguments passed to this will be passed on to the underlying L<Net::Server> implementation.

  # SYNOPSIS
  my $engine = HTTP::Engine->new(
      interface => {
          module => 'ServerSimple',
          args   => {
              host => 'localhost',
              port =>  1978,
              net_server => 'Net::Server::PreForkSimple',
              net_server_configure => {
                  max_servers  => 5,
                  max_requests => 100,
              },
          },
          request_handler => 'main::handle_request',# or CODE ref
      },
  );
  $engine->run;

=back

=head1 AUTHOR

Tokuhiro Matsuno(cpan:tokuhirom)

=head1 THANKS TO

obra++

=head1 SEE ALSO

L<HTTP::Server::Simple>, L<HTTP::Engine>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
