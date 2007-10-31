package Mobirc::ConfigLoader;
use strict;
use warnings;
use YAML ();
use Storable;
use Mobirc::Util;
use Encode;

our $HasKwalify;
eval {
    require Kwalify;
    $HasKwalify++;
};

my $schema = {
    type    => 'map',
    mapping => {
        irc => {
            name     => 'irc',
            desc     => 'settings for irc',
            type     => 'map',
            required => 1,
            mapping  => {
                server => {
                    type     => 'str',
                    required => 1,
                },
                incode => {
                    type     => 'str',
                    required => 1,
                },
                nick   => {
                    type     => 'str',
                    required => 1,
                },
                port => {
                    type     => 'int',
                    required => 1,
                },
                desc => {
                    type     => 'str',
                    required => 1,
                },
                username => {
                    type     => 'str',
                    required => 1,
                },
                password        => { type => 'str', },
                ping_delay      => { type => 'int', },
                reconnect_delay => { type => 'int', },
            }
        },
        httpd => {
            name     => 'httpd',
            type     => 'map',
            required => 1,
            mapping  => {
                lines          => { type => 'int', },
                port           => { type => 'int', required => 1, },
                use_cookie     => { type => 'bool', },
                title          => { type => 'str', },
                cookie_expires => { type => 'str', },
                content_type   => { type => 'str', },
                charset        => { type => 'str', },
                root           => { type => 'str', },
                echo           => { type => 'bool', },
                recent_log_per_page => { type => 'int', },
                filter => {
                    type     => 'seq',
                    sequence => [
                        {
                            type    => 'map',
                            mapping => {
                                module => { type => 'str', required => 1, },
                                config => { type => 'any', },
                            },
                        },
                    ],
                },
                filter => {
                    type     => 'seq',
                    sequence => [
                        {
                            type    => 'map',
                            mapping => {
                                module => { type => 'str', required => 1, },
                                config => { type => 'any', },
                            },
                        },
                    ],
                },
                authorizer => {
                    type     => 'seq',
                    required => 1,
                    sequence => [
                        {
                            type    => 'map',
                            mapping => {
                                module => { type => 'str', required => 1, },
                                config => { type => 'any', required => 1, },
                            },
                        },
                    ],
                },
            },
        },
        global => {
            name    => 'global',
            type    => 'map',
            mapping => {
                pid_fname  => { type => 'str', },
                assets_dir => { type => 'str', },
                keywords   => {
                    type => 'seq',
                    sequence => [
                        {
                            type => 'str'
                        }
                    ],
                },
            }
        },
    },
};

sub load {
    my ( $class, $stuff ) = @_;

    my $config;

    if ( ref $stuff && ref $stuff eq 'HASH' ) {
        $config = Storable::dclone($stuff);
    }
    else {
        local $YAML::Syck::ImplicitUnicode = 1;
        $config = YAML::Syck::LoadFile($stuff);
    }

    if ($HasKwalify) {
        my $res = Kwalify::validate( $schema, $config );
        unless ( $res == 1 ) {
            die "config.yaml validation error : $res";
        }
    } else {
        warn "Kwalify is not installed. Skipping the config validation." if $^W;
    }

    # set default vars.
    $config->{irc}->{ping_delay}       ||= 30;
    $config->{irc}->{reconnect_delay}  ||= 10;
    $config->{httpd}->{charset}        ||= 'cp932';
    $config->{httpd}->{root}           ||= decode( 'utf8', '/' );
    $config->{httpd}->{cookie_expires} ||= '+3d';
    $config->{httpd}->{content_type}   ||= 'text/html; charset=Shift_JIS';
    $config->{httpd}->{echo} = true unless exists $config->{httpd}->{echo};
    $config->{httpd}->{recent_log_per_page} ||= 30;
    $config->{global}->{assets_dir}    ||= File::Spec->catfile( $FindBin::Bin, 'assets' );

    return $config;
}

1;
