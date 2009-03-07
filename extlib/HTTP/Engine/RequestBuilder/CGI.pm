package HTTP::Engine::RequestBuilder::CGI;
use Any::Moose;

with qw(
    HTTP::Engine::Role::RequestBuilder::HTTPBody
    HTTP::Engine::Role::RequestBuilder::ParseEnv
    HTTP::Engine::Role::RequestBuilder
);    

__PACKAGE__
