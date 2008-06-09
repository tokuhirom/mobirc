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
use Encode::JP::Mobile;

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
    my ( $self, $global_context, $c, $uri ) = @_;

    if ( $uri =~ m{^/channel/([^/]+)/gps$} ) {
        my $channel_name = $1;

        my $config = App::Mobirc->context->config;
        my $path   = File::Spec->catfile( $config->{global}->{assets_dir},
            'plugin', 'GPS', 'measure.tt2' );

        local %ENV;
        if ( my $devcap_multimedia = $c->req->header('X-UP-DEVCAP-MULTIMEDIA') )
        {
            $ENV{HTTP_X_UP_DEVCAP_MULTIMEDIA} = $devcap_multimedia;
        }

        my $tt = Template->new( ABSOLUTE => 1 );
        $tt->process(
            $path,
            {
                request      => $c->request,
                req          => $c->req,
                channel_name => $channel_name,
                mobile_agent => $c->req->mobile_agent,
                docroot      => $config->{httpd}->{root},
                port         => $config->{httpd}->{port},
            },
            \my $out
        ) or warn $tt->error;

        $c->res->content_type(
            encode( 'utf8', 'text/html; charset=Shift_JIS' ) );
        $c->res->body($out);
        return 1;
    }
    else {
        return 0;
    }
};

hook httpd => sub {
    my ($self, $global_context, $c, $uri) = @_;

    if ($uri =~ m{^/channel/([^/]+)/gps_do$}) {
        my $channel_name = uri_unescape $1;
        my $inv_geocoder = $self->inv_geocoder;

        my $point = $c->req->mobile_agent->get_location( $c->req->query_params );

        "App::Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->use or die $@;
        my $msg = "App::Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->inv_geocoder($point);
           $msg = uri_escape encode($c->req->mobile_agent->encoding, $msg);

        my $redirect = tt "/channels/[% channel_name | uri %]?msg=L:[% msg %]";
        $c->res->redirect($redirect);
        return 1;
    } else {
        return 0;
    }
};

1;
