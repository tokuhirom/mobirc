#!/usr/bin/perl

package HTTP::Engine::Role::RequestBuilder;
use Any::Moose '::Role';

# initialize reading structures
requires "_build_read_state";

# connection info is a hash of address, port, https info, user, etc.
# stuff that goes in env.
requires "_build_connection_info";
requires "_build_hostname";

# parsed from the HTTP message or provided explicitly or from connection->{env}
requires "_build_uri";
requires "_build_headers";
requires "_build_cookies";

# these two 
requires "_build_raw_body";
requires "_build_http_body";

__PACKAGE__

__END__
