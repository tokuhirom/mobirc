package Mobirc::Plugin::GPS;
use strict;
use warnings;
use HTTP::MobileAgent;
use HTTP::MobileAgent::Plugin::Locator;
use Template;
use Encode;
use URI;
use URI::Escape;
use Geo::Coordinates::Converter;
use UNIVERSAL::require;

sub register {
    my ($class, $global_context, $conf) = @_;

    $global_context->register_hook(
        channel_page_option => sub {
            my ($channel, $global_context) = @_;

            my $tt = Template->new;
            # TODO: split template string to assets dir.
            $tt->process(
                \qq{<a href="/channel/[% channel.name | uri %]/gps?time=[% time %]e"'>gps</a>},
                { channel => $channel, time => time() },
                \my $out
            ) or warn $tt->error;
            return $out;
        },
    );

    $global_context->register_hook(
        httpd => sub {
            my ($c, $uri) = @_;

            if ($uri =~ m{^/channel/([^/]+)/gps\?time=}) {
                my $channel_name = $1;

                my $path = File::Spec->catfile($c->{config}->{global}->{assets_dir}, 'plugin', 'GPS', 'measure.tt2');

                local %ENV;
                if (my $devcap_multimedia = $c->{req}->header('X-UP-DEVCAP-MULTIMEDIA')) {
                    $ENV{HTTP_X_UP_DEVCAP_MULTIMEDIA} = $devcap_multimedia;
                }

                my $response = HTTP::Response->new(200);
                $response->push_header( 'Content-type' => encode('utf8', $c->{config}->{httpd}->{content_type}) );
                my $tt = Template->new(ABSOLUTE => 1);
                $tt->process(
                    $path,
                    {
                        request      => $c->{request},
                        req          => $c->{req},
                        channel_name => $channel_name,
                        mobile_agent => $c->{mobile_agent},
                        docroot      => $c->{config}->{httpd}->{root},
                        port         => $c->{config}->{httpd}->{port},
                    },
                    \my $out
                ) or warn $tt->error;
                $response->content($out);
                return $response;
            }
        },
    );

    $global_context->register_hook(
        httpd => sub {
            my ($c, $uri) = @_;

            if ($uri =~ m{^/channel/([^/]+)/gps_do}) {
                my $channel_name = $1;
                my $inv_geocoder = $conf->{inv_geocoder} || 'EkiData';

                my $point = $c->{mobile_agent}->get_location( +{ URI->new($uri)->query_form } );

                "Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->use or die $@;
                my $msg = "Mobirc::Plugin::GPS::InvGeocoder::$inv_geocoder"->inv_geocoder($point);

                my $res = HTTP::Response->new(302);
                my $abs_uri = 'http://' . $c->{req}->header('Host') . $c->{config}->{httpd}->{root} . "channels/$channel_name?msg=" . uri_escape(encode('utf8', "L:$msg"));
                $res->header('Location' => $abs_uri);
                $res;
            }
        },
    );
}

1;
