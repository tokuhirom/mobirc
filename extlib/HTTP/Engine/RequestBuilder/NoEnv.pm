package HTTP::Engine::RequestBuilder::NoEnv;
use Any::Moose;

with qw(
    HTTP::Engine::Role::RequestBuilder::Standard
    HTTP::Engine::Role::RequestBuilder::HTTPBody
    HTTP::Engine::Role::RequestBuilder::NoEnv
    HTTP::Engine::Role::RequestBuilder
);

1;
