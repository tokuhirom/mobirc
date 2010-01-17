package HTTP::Engine;
use 5.008;
use Any::Moose;
our $VERSION = '0.03003';
use HTTP::Engine::Request;
use HTTP::Engine::Response;
use HTTP::Engine::Types::Core qw( Interface );

has 'interface' => (
    is      => 'ro',
    isa => Interface,
    coerce  => 1,
    handles => [ qw(run) ],
);

no Any::Moose;
__PACKAGE__->meta->make_immutable(inline_destructor => 1);
1;
__END__

=for stopwords middlewares Middleware middleware nothingmuch kan Stosberg otsune

=encoding utf8

=head1 NAME

HTTP::Engine - Web Server Gateway Interface and HTTP Server Engine Drivers

=head1 SYNOPSIS

  use HTTP::Engine;
  my $engine = HTTP::Engine->new(
      interface => {
          module => 'ServerSimple',
          args   => {
              host => 'localhost',
              port =>  1978,
          },
          request_handler => \&handle_request,
      },
  );
  $engine->run;

  sub handle_request {
      my $req = shift;
      HTTP::Engine::Response->new( body => "Hello world" );
  }

=head1 DESCRIPTION

HTTP::Engine abstracts handling the input and output of various web
server environments, including CGI, mod_perl and FastCGI. Most of the
code is ported over from Catalyst::Engine.

If you're familiar with WSGI for Python or Rack for Ruby, HTTP::Engine
exactly does the same thing, for Perl.

=head1 WHY WOULD YOU USE HTTP::ENGINE

L<CGI.pm> is popular under the CGI environment and L<Apache::Request>
is great for better performance under mod_perl environment. The
problem is, these HTTP request and response handling abstractions have
incompatible interfaces, and it's not easy to switch between them.

HTTP::Engine prepareas a L<HTTP::Engine::Request> object for you which
is optimized for your current environment, and pass that to your
request handler. Your request handler then returns a
L<HTTP::Engine::Response> object, which we communicate back to the
server for you.

L<HTTP::Engine::Request> covers the bases of common request process
tasks, like handling GET and POST parameters, parsing HTTP cookies and
processing file uploads. Unlike CGI.pm, but like most other web
programming languages, it allows you to mix GET and POST parameters.

And importantly, it allows you to seamlessly move your code from CGI
to a persistent environment (like mod_perl or FastCGI) without
rewriting your code. At the same time, you'll maintain the possibility
of additional performance benefits, as HTTP::Engine can transparently
take advantage of native mod_perl functions when they are available.

=head1 MIDDLEWARE

Middleware is a framwork to extend HTTP::Engine, much like
Catalyst::Plugin for Catalyst. Please see L<HTTP::Engine::Middleware>.

=head1 INTERFACES

Interfaces are the actual environment-dependent components which handles
the actual interaction between your clients and the application.

For example, in CGI mode, you can write to STDOUT and expect your clients to
see it, but in mod_perl, you may need to use $r-E<gt>print instead.

Interfaces are the actual layers that does the interaction. HTTP::Engine
currently supports the following:

# XXX TODO: Update the list

=over 4

=item HTTP::Engine::Interface::ServerSimple

=item HTTP::Engine::Interface::FastCGI

=item HTTP::Engine::Interface::CGI

=item HTTP::Engine::Interface::Test

for test code interface

=item HTTP::Engine::Interface::ModPerl

experimental

=item HTTP::Engine::Interface::Standalone

old style

=back

Interfaces can be specified as part of the HTTP::Engine constructor:

  my $interface = HTTP::Engine::Interface::FastCGI->new(
    request_handler => ...
  );
  HTTP::Engine->new(
    interface => $interface
  )->run();

Or you can let HTTP::Engine instantiate the interface for you:

  HTTP::Engine->new(
    interface => {
      module => 'FastCGI',
      args   => {
      }
      request_handler => ...
    }
  )->run();


=head1 COMMUNITY

The community can be found via:

  IRC: irc.perl.org#http-engine

  Mailing list: http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/http-engine

  GitHub: http://github.com/http-engine/HTTP-Engine

  Twitter: http://twitter.com/httpengine

=head1 ADDITIONAL DOCUMENTATIONS

L<http://en.wikibooks.org/wiki/Perl_Programming/HTTP::Engine> writing by gugod++.

=head1 AUTHOR

Kazuhiro Osawa E<lt>yappo <at> shibuya <döt> plE<gt>

Daisuke Maki

tokuhirom

nyarla

marcus

hidek

dann

typester (Interface::FCGI)

lopnor

nothingmuch

kan

Mark Stosberg (documentation)

walf443

kawa0117

mattn

otsune

gugod

stevan

hirose31

fujiwara

miyagawa

Shawn M Moore

=head1 SEE ALSO

L<HTTP::Engine::Middleware>,
L<HTTP::Engine::Compat>,
L<HTTPEx::Declare>,
L<Any::Moose>,
L<Mouse>,
L<Moose>

=head1 REPOSITORY

We moved to GitHub.

  git clone git://github.com/http-engine/HTTP-Engine.git

HTTP::Engine's Git repository is hosted at L<http://github.com/http-engine/HTTP-Engine>.
patches and collaborators are welcome.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
