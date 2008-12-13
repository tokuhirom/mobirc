package HTTP::Engine::RequestBuilder::CGI;
use Mouse;

with $_ for qw(
    HTTP::Engine::Role::RequestBuilder::HTTPBody
    HTTP::Engine::Role::RequestBuilder::ParseEnv
    HTTP::Engine::Role::RequestBuilder
);

__PACKAGE__
