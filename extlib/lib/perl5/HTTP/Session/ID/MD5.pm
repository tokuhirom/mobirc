use warnings;
use strict;

package HTTP::Session::ID::MD5;
use Digest::MD5  ();
use Time::HiRes  ();

# Digest::MD5 was first released with perl 5.007003

sub generate_id {
    my ($class, $sid_length) = @_;
    my $unique = $ENV{UNIQUE_ID} || ( [] . rand() );
    return substr( Digest::MD5::md5_hex( Time::HiRes::gettimeofday() . $unique ), 0, $sid_length );
}

1;
