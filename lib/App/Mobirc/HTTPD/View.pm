package App::Mobirc::HTTPD::View;
use strict;
use warnings;
use Template::Declare;
use Module::Find;
my @templates = useall 'App::Mobirc::HTTPD::Template';
Template::Declare->init(roots => [@templates]);

sub show {
    my ($class, @args) = @_;
    Template::Declare->show(@args);
}

1;
