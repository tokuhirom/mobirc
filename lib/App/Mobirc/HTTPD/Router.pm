package App::Mobirc::HTTPD::Router;
use strict;
use warnings;
use HTTPx::Dispatcher;

connect ''                      => { controller => 'Mobile', action => 'index' };
connect 'channels/:channel'     => { controller => 'Mobile', action => 'show_channel' };
connect 'ajax/'                 => { controller => 'Ajax',   action => 'base' };
connect 'ajax/:action'          => { controller => 'Ajax' };
connect '([a-z]+).(js|css)'     => { controller => 'Static', action => 'deliver' };
connect ':action'               => { controller => 'Mobile' };

1;
