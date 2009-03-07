package HTTP::Engine::Middleware::Profile::Role;
use Any::Moose '::Role';

requires 'start';
requires 'end';
requires 'report';

1;
