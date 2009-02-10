package HTTP::MobileAttribute::Request;
use strict;
use warnings;
use Carp;
use Class::Inspector;
use Scalar::Util qw/blessed/;
use HTTP::MobileAttribute::Request::Env;
use HTTP::MobileAttribute::Request::Apache; # for apache1
use HTTP::MobileAttribute::Request::APRTable; # for apache2
use HTTP::MobileAttribute::Request::HTTPHeaders;

sub new {
    my ($class, $stuff) = @_;

    # This is the not-so-sexy approach that uses less code than the original
    my $impl_class;
    if (! $stuff || ! ref $stuff ) {
        # first, if $stuff is not defined or is not a reference...
        $impl_class = join("::", __PACKAGE__, "Env");
    } elsif (blessed($stuff)) {
        # or, if it's blessed, check if they are of appropriate types
        foreach my $pkg qw(Apache HTTP::Headers HTTP::Headers::Fast APR::Table) {
            if ($stuff->isa($pkg)) {
                $impl_class = join("::", __PACKAGE__, $pkg);
                 # XXX Hack. Will only work for HTTPHeaders & APRTable
                $impl_class =~ s/HTTP::Headers(?:::Fast)?$/HTTPHeaders/;
                $impl_class =~ s/APR::Table$/APRTable/;
                last;
            }
        }
    }

    if (! $impl_class) {
        croak "unknown request type: $stuff";
    }

    return $impl_class->new($stuff);
}

1;
