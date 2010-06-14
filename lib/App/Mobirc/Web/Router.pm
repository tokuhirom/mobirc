package App::Mobirc::Web::Router;
use strict;
use warnings;
use Router::Simple::Declare;

my $router = router {
    connect('/'                         => { controller => 'Root', action => 'index' });
    connect('/static/{filename:.+}'     => { controller => 'Static', action => 'deliver' });

    connect('/android/'                 => { controller => 'Android', action => 'index' });
    connect('/android/:action'          => { controller => 'Android', });

    connect('/ajax/'                    => { controller => 'Ajax',   action => 'base' });
    connect('/account/:action',         => { controller => 'Account' });
    connect('/mobile/'                  => { controller => 'Mobile',   action => 'index' });
    connect('/mobile-ajax/'             => { controller => 'MobileAjax',   action => 'index' });
    connect('/mobile-ajax/:action'      => { controller => 'MobileAjax', });
    connect('/iphone/'                  => { controller => 'IPhone', action => 'base' });
    connect('/iphone/:action'           => { controller => 'IPhone', });
    connect('/iphone2/'                  => { controller => 'IPhone2', action => 'base' });
    connect('/iphone2/:action'           => { controller => 'IPhone2', });
    connect('/ajax/:action'             => { controller => 'Ajax' });
    connect('/mobile/:action'           => { controller => 'Mobile' });
    connect('/api/:action'             => { controller => 'API' });
};

sub match {
    my ($class, $req) = @_;
    $router->match($req);
}

1;
