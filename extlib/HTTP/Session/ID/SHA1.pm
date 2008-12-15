use warnings;
use strict;

package HTTP::Session::ID::SHA1;
use Digest::SHA1 ();
use Time::HiRes  ();

sub generate_id {
    my ($class, $sid_length) = @_;
    my $unique = $ENV{UNIQUE_ID} || ( [] . rand() );
    return substr( Digest::SHA1::sha1_hex( Time::HiRes::gettimeofday() . $unique ), 0, $sid_length );
}

1;
