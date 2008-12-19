package App::Mobirc::ConfigLoader;
use strict;
use warnings;
use Config::Tiny;
use Storable;
use App::Mobirc::Util;
use Encode;

sub load {
    my ( $class, $stuff ) = @_;

    my $config;

    if ( ref $stuff && ref $stuff eq 'HASH' ) {
        $config = Storable::dclone($stuff);
    }
    else {
        open my $fh, '<:utf8', $stuff or die "cannot open file: $!";
        my $ini = Config::Tiny->read_string(do { local $/; <$fh> });
        close $fh;

        my $global = delete $ini->{_};
        for my $key (qw/keywords stopwords/) {
            if ($global->{$key}) {
                $global->{$key} = [split /\s*,\s*/, $global->{$key}];
            }
        }
        $config = +{
            global => $global,
            plugin => [ map { +{ module => $_, config => $ini->{$_} } } keys %$ini],
        };
    }

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

