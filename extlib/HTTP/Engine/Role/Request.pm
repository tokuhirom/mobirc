package HTTP::Engine::Role::Request;
use Any::Moose '::Role';

requires qw(
    context

    headers header
    content_encoding
    content_length
    content_type
    referer
    user_agent
    cookies

    cookie

    connection_info

    uri base path
    uri_with
    absolute_url

    param
    parameters
    query_parameters body_parameters

    as_http_request

    content
);

1;
