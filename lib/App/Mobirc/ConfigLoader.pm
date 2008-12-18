package App::Mobirc::ConfigLoader;
use strict;
use warnings;
use YAML ();
use Storable;
use App::Mobirc::Util;
use Encode;

our $HasKwalify;
eval {
    require Kwalify;
    $HasKwalify++;
};

my $schema = {
    type    => 'map',
    mapping => {
        plugin => {
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
        global => {
            name    => 'global',
            type    => 'map',
            mapping => {
                password   => { type => 'str', },
                mobileid   => { type => 'str', },
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
                stopwords   => {
                    type => 'seq',
                    sequence => [
                        {
                            type => 'str'
                        }
                    ],
                },
                recent_log_per_page => { type => 'int', },
                log_max             => { type => 'int', },
                root                => { type => 'str', },
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
        open my $fh, '<:utf8', $stuff or die $!;
        $config = YAML::LoadFile($fh);
        close $fh;
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
    $config->{global}->{assets_dir}    ||= File::Spec->catfile( $FindBin::Bin, 'assets' );

    return $config;
}

1;
__END__

=head1 NAME

App::Mobirc::ConfigLoader - configuration file loader for moxy

=head1 DESCRIPTION

INTERNAL USE ONLY

=head1 SEE ALSO

L<App::Mobirc>

