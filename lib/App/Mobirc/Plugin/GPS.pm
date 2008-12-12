package App::Mobirc::Plugin::GPS;
use strict;
use MooseX::Plaggerize::Plugin;
use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Locator;
use Template;
use Encode;
use URI;
use URI::Escape;
use Geo::Coordinates::Converter;
use UNIVERSAL::require;
use String::TT ':all';
use App::Mobirc::Validator;

has inv_geocoder => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Null',
);

hook channel_page_option => sub {
    my ( $self, $global_context, $channel ) = @_;

    return tt qq{<a href="/channel/[% channel.name | uri %]/gps">gps</a>};
};

hook httpd => sub {
    my ( $self, $global_context, $req ) = validate_hook('httpd', @_);

    if ( $req->path =~ m{^/channel/([^/]+)/gps$} ) {
        my $channel_name = $1;

        my $config = App::Mobirc->context->config;
        my $path   = File::Spec->catfile( $config->{global}->{assets_dir},
            'plugin', 'GPS', 'measure.tt2' );

        local %ENV;
        if ( my $devcap_multimedia = $req->header('X-UP-DEVCAP-MULTIMEDIA') )
        {
            $ENV{HTTP_X_UP_DEVCAP_MULTIMEDIA} = $devcap_multimedia;
        }

        my $tt = Template->new( ABSOLUTE => 1 );
        $tt->process(
            $path,
            {
                request      => $req, # FIXME: why we needs two same parameters?
                req          => $req,
                channel_name => $channel_name,
                mobile_agent => $req->mobile_agent,
                docroot      => $config->{httpd}->{root},
                port         => $config->{httpd}->{port},
            },
            \my $out
        ) or warn $tt->error;

        return HTTP::Engine::Response->new(
            content_type => 'text/html; charset=Shift_JIS',
            body         => $out,
        );
    }
    else {
        return;
    }
};

hook httpd => sub {
    my ( $self, $global_context, $req ) = validate_hook('httpd', @_);

    if ($req->path =~ m{^/channel/([^/]+)/gps_do$}) {
        my $channel_name = decode_utf8 uri_unescape $1;
        my $channel = $global_context->server->get_channel($channel_name);
        my $inv_geocoder = $self->inv_geocoder;

        my $point = $req->mobile_agent->get_location( $req->query_params );

        "App::Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->use or die $@;
        my $msg = "App::Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->inv_geocoder($point);
           $msg = uri_escape encode($req->mobile_agent->encoding, $msg);

        my $redirect = sprintf('/mobile/channel?channel=%s&msg=%s', $channel->name_urlsafe_encoded, $msg);
        return HTTP::Engine::Response->new(
            status  => 302,
            headers => HTTP::Headers->new( Location => $redirect )
        );
    } else {
        return;
    }
};

1;
