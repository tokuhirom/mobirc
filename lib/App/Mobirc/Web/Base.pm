package App::Mobirc::Web::Base;
use strict;
use warnings;
use base qw/Exporter/;
use Encode qw/decode_utf8/;
use App::Mobirc::Util qw/global_context/;
use Carp qw(croak);

our @EXPORT = qw/global_context config server web_context session req mobile_attribute param is_iphone/;

sub config ()           { global_context->config }
sub server ()           {
    my $server_id = param('server') // croak "Missing server name";
    global_context->get_server($server_id);
}

sub web_context ()      { App::Mobirc::Web::Handler->web_context }
sub session ()          { web_context->session }
sub req ()              { web_context->req }
sub mobile_attribute () { web_context->mobile_attribute() }
sub param ($)           { decode_utf8( scalar req->param( $_[0] ) ) }

sub is_iphone {
    ( mobile_attribute()->user_agent =~ /(?:iPod|iPhone)/ ) ? 1 : 0;
}


1;
