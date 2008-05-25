package App::Mobirc::HTTPD::View;
use strict;
use warnings;
use Template::Declare;
use App::Mobirc::HTTPD::Template::IRCMessage;

Template::Declare->init(roots => ['App::Mobirc::HTTPD::Template::IRCMessage']);

sub show {
    my ($class, @args) = @_;
    Template::Declare->show(@args);
}

1;
