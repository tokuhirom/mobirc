package HTTP::Engine::Role::Response;
use Any::Moose '::Role';

requires qw(
    context

    body

    status

    headers
    cookies
    location
    header
    content_type content_length content_encoding

    protocol
    redirect

    set_http_response

    finalize
);

1;

