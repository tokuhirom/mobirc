package HTTP::Engine;
use 5.00800;
use Mouse;
our $VERSION = '0.1.1';
use HTTP::Engine::Request;
use HTTP::Engine::Request::Upload;
use HTTP::Engine::Response;
use HTTP::Engine::Types::Core qw( Interface );

has 'interface' => (
    is      => 'ro',
    isa => Interface,
    coerce  => 1,
    handles => [ qw(run) ],
);

no Mouse;
$_->meta->make_immutable(inline_destructor => 1) for qw(
    HTTP::Engine::Request::Upload
    HTTP::Engine::Request
    HTTP::Engine::Response
    HTTP::Engine
);
1;
__END__

=for stopwords middlewares Middleware middleware nothingmuch kan Stosberg otsune

=encoding utf8

=head1 NAME

HTTP::Engine - Web Server Gateway Interface and HTTP Server Engine Drivers (Yet Another Catalyst::Engine)

=head1 SYNOPSIS

  use HTTP::Engine;
  my $engine = HTTP::Engine->new(
      interface => {
          module => 'ServerSimple',
          args   => {
              host => 'localhost',
              port =>  1978,
          },
          request_handler => 'main::handle_request',# or CODE ref
      },
  );
  $engine->run;

  use Data::Dumper;
  sub handle_request {
      my $req = shift;
      HTTP::Engine::Response->new( body => Dumper($req) );
  }


=head1 MILESTONE

=head2 0.x.x

A substantial document. (A tutorial, the Cookbook and hacking HowTo)

=head2 0.1.x (Now here)

Improvement in performance and resource efficiency.
Most specifications are frozen.
The specification is changed by the situation.

I want to perform Async support. (AnyEvent? Danga::Socket? IO::Async?)

=head2 0.0.99_x

It is an adjustment stage to the following version.

=head2 0.0.x

Version 0.0.x is a concept release, the internal interface is still fluid. 
It is mostly based on the code of Catalyst::Engine.

=head1 COMPATIBILITY

version over 0.0.13 is incompatible of version under 0.0.12.

using L<HTTP::Engine::Compat> module if you want compatibility of version under 0.0.12.

version 0.0.13 is unsupported of context and middleware.

=head1 DESCRIPTION

HTTP::Engine abstracts handling the input and output of various web server
environments, including CGI, mod_perl and FastCGI. 

While some people use <CGI.pm>  in a CGI environment, but switch
<Apache::Request> under mod_perl for better performance, these HTTP request
abstractions have incompatible interfaces, so it is not easy to switch between
them.

HTTP::Engine will prepare a L<HTTP::Engine::Request> object for you which is
optimized for your current environment, and pass that to your request handler.
Your request handler than prepares a L<HTTP::Engine::Response> object, which we
communicate back to the server for you. 

L<HTTP::Engine::Request> covers the bases of common request process tasks, like
handling GET and POST parameters and processing file uploads. Unlike CGI.pm,
but like most other web programming languages, it allows you to mix GET and
POST parameters.

And importantly, it allows you to seamlessly move your code from CGI to a
persistent without rewriting your code. At the same time, you'll maintain the
possibility of additional performance benefits, as HTTP::Engine can
transparently take advantage of native mod_perl functions when they are
available.

=head1 COMMUNITY

The community can be found via:

  IRC: irc.perl.org#http-engine irc.freenode.net#coderepos

  Wiki Page: http://coderepos.org/share/wiki/HTTP%3A%3AEngine

  SVN: http://svn.coderepos.org/share/lang/perl/HTTP-Engine  

  Trac: http://coderepos.org/share/browser/lang/perl/HTTP-Engine

  Mailing list: http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/http-engine

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

=head1 CONCEPT

=over 4

=item HTTP::Engine is Not

    session manager
    authentication manager
    URL dispatcher
    model manager
    toy
    black magick

=item HTTP::Engine is

    HTTP abstraction layer

=item HTTP::Engine's ancestry

    WSGI
    Rack

=back

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

=head1 SEE ALSO

L<HTTP::Engine::Compat>,
L<HTTPEx::Declare>,
L<Mouse>

=head1 REPOSITORY

  svn co http://svn.coderepos.org/share/lang/perl/HTTP-Engine/trunk HTTP-Engine

HTTP::Engine's Subversion repository is hosted at L<http://coderepos.org/share/>.
patches and collaborators are welcome.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
