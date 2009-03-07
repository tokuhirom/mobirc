
package HTTP::Server::Simple::CGI;

use base qw(HTTP::Server::Simple HTTP::Server::Simple::CGI::Environment);
use strict;
use warnings;

use CGI ();

use vars qw($VERSION $default_doc);
$VERSION = $HTTP::Server::Simple::VERSION;

=head1 NAME

HTTP::Server::Simple::CGI - CGI.pm-style version of HTTP::Server::Simple

=head1 DESCRIPTION

HTTP::Server::Simple was already simple, but some smart-ass pointed
out that there is no CGI in HTTP, and so this module was born to
isolate the CGI.pm-related parts of this handler.


=head2 accept_hook

The accept_hook in this sub-class clears the environment to the
start-up state.

=cut

sub accept_hook {
    my $self = shift;
    $self->setup_environment(@_);
}

=head2 post_setup_hook

Initializes the global L<CGI> object, as well as other environment
settings.

=cut

sub post_setup_hook {
    my $self = shift;
    $self->setup_server_url;
    CGI::initialize_globals();
}

=head2 setup

This method sets up CGI environment variables based on various
meta-headers, like the protocol, remote host name, request path, etc.

See the docs in L<HTTP::Server::Simple> for more detail.

=cut

sub setup {
    my $self = shift;
    $self->setup_environment_from_metadata(@_);
}

=head2 handle_request CGI

This routine is called whenever your server gets a request it can
handle.

It's called with a CGI object that's been pre-initialized.
You want to override this method in your subclass


=cut

$default_doc = ( join "", <DATA> );

sub handle_request {
    my ( $self, $cgi ) = @_;

    print "HTTP/1.0 200 OK\r\n";    # probably OK by now
    print "Content-Type: text/html\r\nContent-Length: ", length($default_doc),
        "\r\n\r\n", $default_doc;
}

=head2 handler

Handler implemented as part of HTTP::Server::Simple API

=cut

sub handler {
    my $self = shift;
    my $cgi  = new CGI();
    eval { $self->handle_request($cgi) };
    if ($@) {
        my $error = $@;
        warn $error;
    }
}

1;

__DATA__
<html>
  <head>
    <title>Hello!</title>
  </head>
  <body>
    <h1>Congratulations!</h1>

    <p>You now have a functional HTTP::Server::Simple::CGI running.
      </p>

    <p><i>(If you're seeing this page, it means you haven't subclassed
      HTTP::Server::Simple::CGI, which you'll need to do to make it
      useful.)</i>
      </p>
  </body>
</html>
