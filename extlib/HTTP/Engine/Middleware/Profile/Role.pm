package HTTP::Engine::Middleware::Profile::Role;
use Mouse::Role;

requires 'start';
requires 'end';
requires 'report';

1;
