package App::Mobirc::HTTPD::View;
use strict;
use warnings;
use Template::Declare;
use App::Mobirc::HTTPD::Template::IRCMessage;
use App::Mobirc::HTTPD::Template::Pages;

Template::Declare->init(roots => ['App::Mobirc::HTTPD::Template::IRCMessage', 'App::Mobirc::HTTPD::Template::Pages']);

sub show {
    my ($class, @args) = @_;
    Template::Declare->show(@args);
}

1;
