package App::Mobirc::Web::Router;
use strict;
use warnings;
use Router::Simple::Declare;

my $router = router {
    connect('/'                         => { controller => 'Root', action => 'index' });
    connect('/static/{filename:.+}'     => { controller => 'Static', action => 'deliver' });

    connect('/ajax/'                    => { controller => 'Ajax',   action => 'base' });
    connect('/account/:action',         => { controller => 'Account' });
    connect('/mobile/'                  => { controller => 'Mobile',   action => 'index' });
    connect('/smartphone/'                  => { controller => 'SmartPhone', action => 'base' });
    connect('/smartphone/*'                 => { controller => 'SmartPhone', action => 'base' });
    connect('/ajax/:action'             => { controller => 'Ajax' });
    connect('/mobile/:action'           => { controller => 'Mobile' });
    connect('/api/:action'             => { controller => 'API' });
};

sub match {
    my ($class, $req) = @_;
    $router->match($req);
}

1;
