package HTTP::Engine::Interface::ServerSimple;
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

sub run {
    my ($self, ) = @_;

    my $headers;
    my %setup;
    my $server;
    $server = Mouse::Meta::Class
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
                    $headers->header(@$args);
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
            },
            cache => 1
        )->name->new(
            $self->port
        );
    $server->host($self->host);
    $server->run;
}

__INTERFACE__

__END__

=head1 NAME

HTTP::Engine::Interface::ServerSimple - HTTP::Server::Simple interface for HTTP::Engine

=head1 DESCRIPTION

HTTP::Engine::Plugin::Interface::ServerSimple is wrapper for HTTP::Server::Simple.

HTTP::Server::Simple is flexible web server.And it can use Net::Server, so you can make it preforking or using Coro.

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
