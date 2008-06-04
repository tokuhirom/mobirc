package App::Mobirc::Web::Router;
use strict;
use warnings;
use HTTPx::Dispatcher;

connect ''                         => { controller => 'Root', action => 'index' };
connect 'channels/:channel'        => { controller => 'Mobile', action => 'show_channel' };
connect 'ajax/'                    => { controller => 'Ajax',   action => 'base' };
connect 'mobile/'                  => { controller => 'Mobile',   action => 'index' };
connect 'mobile-ajax/'             => { controller => 'MobileAjax',   action => 'index' };
connect 'mobile-ajax/:action'      => { controller => 'MobileAjax', };
connect 'ajax/:action'             => { controller => 'Ajax' };
connect 'static/:filename'         => { controller => 'Static', action => 'deliver' };
connect 'mobile/:action'           => { controller => 'Mobile' };
connect ':action'                  => { controller => 'Mobile' };

1;
