package HTTP::MobileAttribute::Plugin::Locator;
use strict;
use warnings;
use base qw/HTTP::MobileAttribute::Plugin/;
use UNIVERSAL::require;
use Carp;
use constant {
    LOCATOR_AUTO_FROM_COMPLIANT => 1,
    LOCATOR_AUTO                => 2,
    LOCATOR_GPS                 => 3,
    LOCATOR_BASIC               => 4,
};
use Exporter 'import';

our @EXPORT_OK = qw/LOCATOR_AUTO_FROM_COMPLIANT LOCATOR_AUTO  LOCATOR_GPS LOCATOR_BASIC/;
our %EXPORT_TAGS = (
    'constants' => [@EXPORT_OK],
);

__PACKAGE__->depends(['IS', 'GPS', 'IS::ThirdForce']);

sub get_location :Method {
    my ($self, $c, $stuff, $option_ref) = @_;
    my $params = _prepare_params( $stuff );
    return $self->_locator($c, $params, $option_ref)->get_location($params);
}

sub _locator {
    my ($self, $c, $params, $option_ref) = @_;
    my $suffix = _get_carrier_locator($c, $params, $option_ref);
    my $klass = "@{[ ref $self ]}::$suffix";
    $klass->use or die $@;
    return $klass->new();
}

sub _get_carrier_locator {
    my ( $agent, $params, $option_ref ) = @_;

    my $carrier = $agent->carrier_longname;
    croak( "Invalid mobile user agent: " . $agent->user_agent ) if $carrier eq 'NonMobile';

    my $locator;
    if (   !defined $option_ref
        || !defined $option_ref->{locator}
        || $option_ref->{locator} eq LOCATOR_AUTO_FROM_COMPLIANT )
    {
        $locator = $agent->gps_compliant ? 'GPS' : 'BasicLocation';
    }
    elsif ( $option_ref->{locator} eq LOCATOR_AUTO ) {
        $locator =
          _is_gps_parameter( $agent, $params ) ? 'GPS' : 'BasicLocation';
    }
    elsif ( $option_ref->{locator} eq LOCATOR_GPS ) {
        $locator = 'GPS';
    }
    elsif ( $option_ref->{locator} eq LOCATOR_BASIC ) {
        $locator = 'BasicLocation';
    }
    else {
        croak( "Invalid locator: " . $option_ref->{locator} );
    }

    return $carrier . '::' . $locator;
}

# to check whether parameter is gps or basic
sub _is_gps_parameter {
    my ( $agent, $stuff ) = @_;
    my $params = _prepare_params($stuff);
    if ( $agent->is_docomo ) {
        return !defined $params->{AREACODE};
    }
    elsif ( $agent->is_ezweb ) {
        return defined $params->{datum} && $params->{datum} =~ /^\d+$/;
    }
    elsif ( $agent->is_softbank ) {
        return defined $params->{pos};
    }
    elsif ( $agent->is_airh_phone ) {
        return;
    }
    else {
        croak( "Invalid mobile user agent: " . $agent->user_agent );
    }
}

sub _prepare_params {
    my $stuff = shift;
    if ( ref $stuff && eval { $stuff->can('param') } ) {
        return +{
            map {
                $_ => ( scalar( @{ [ $stuff->param($_) ] } ) > 1 )
                  ? [ $stuff->param($_) ]
                  : $stuff->param($_)
              } $stuff->param
        };
    }
    else {
        return $stuff;
    }
}

1;
__END__

=head1 NAME

HTTP::MobileAttribute::Plugin::Locator - location support

=head1 SYNOPSIS

    use HTTP::MobileAttribute plugins => [qw/Locator/];

    my $ma = HTTP::MobileAttribute->new($r);
    $ma->get_location($r);

=head1 DESCRIPTION

This module is copy & pasted from HTTP::MobileAgent::Plugin::Locator.

=head1 METHODS

=head2 get_location([params], $option_ref);

return Geo::Coordinates::Converter::Point instance formatted if specify gps or basic location parameters sent from carrier. The parameters are different by each carrier.

This method accept a Apache instance, CGI instance or hashref of query parameters.

=over

=item $option_ref->{locator}

select locator class algorithm option.

LOCATOR_AUTO_FROM_COMPLIANT
    auto detect locator from gps compliant. This is I<default>.

LOCATOR_AUTO
    auto detect locator class from params.

LOCATOR_GPS
    select GPS class.

LOCATOR_BASIC
    select BasicLocation class.

=back

=head1 AUTHORS

copy & pasted by Tokuhiro Matsuno

L<HTTP::MobileAgent::Plugin::Locator> is written by Yoshiki Kurihara

=head1 SEE ALSO

L<HTTP::MobileAgent::Plugin::Locator>

