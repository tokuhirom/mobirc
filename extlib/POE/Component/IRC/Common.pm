package POE::Component::IRC::Common;

use strict;
use warnings;

our $VERSION = '5.18';

require Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(
    u_irc l_irc parse_mode_line parse_ban_mask matches_mask matches_mask_array
    parse_user irc_ip_get_version irc_ip_is_ipv4 irc_ip_is_ipv6 has_color
    has_formatting strip_color strip_formatting NORMAL BOLD UNDERLINE REVERSE
    WHITE BLACK DARK_BLUE DARK_GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN
    TEAL CYAN LIGHT_BLUE MAGENTA DARK_GREY LIGHT_GREY
);
our %EXPORT_TAGS = ( ALL => [@EXPORT_OK] );

my ($ERROR, $ERRNO);

use constant {
    NORMAL      => "\x0f",
    
    # formatting
    BOLD        => "\x02",
    UNDERLINE   => "\x1f",
    REVERSE     => "\x16",
    ITALIC      => "\x1d",
    FIXED       => "\x11",
    
    # mIRC colors
    WHITE       => "\x0300",
    BLACK       => "\x0301",
    DARK_BLUE   => "\x0302",
    DARK_GREEN  => "\x0303",
    RED         => "\x0304",
    BROWN       => "\x0305",
    PURPLE      => "\x0306",
    ORANGE      => "\x0307",
    YELLOW      => "\x0308",
    LIGHT_GREEN => "\x0309",
    TEAL        => "\x0310",
    CYAN        => "\x0311",
    LIGHT_BLUE  => "\x0312",
    MAGENTA     => "\x0313",
    DARK_GREY   => "\x0314",
    LIGHT_GREY  => "\x0315",
};

sub u_irc {
    my $value = shift || return;
    my $type = shift || 'rfc1459';
    $type = lc $type;

    if ( $type eq 'ascii' ) {
        $value =~ tr/a-z/A-Z/;
    }
    elsif ( $type eq 'strict-rfc1459' ) {
        $value =~ tr/a-z{}|/A-Z[]\\/;
    }
    else {
        $value =~ tr/a-z{}|^/A-Z[]\\~/;
    }

    return $value;
}

sub l_irc {
    my $value = shift || return;
    my $type = shift || 'rfc1459';
    $type = lc $type;

    if ( $type eq 'ascii' ) {
        $value =~ tr/A-Z/a-z/;
    }
    elsif ( $type eq 'strict-rfc1459' ) {
        $value =~ tr/A-Z[]\\/a-z{}|/;
    }
    else {
        $value =~ tr/A-Z[]\\~/a-z{}|^/;
    }

    return $value;
}

sub parse_mode_line {
    my @args = @_;

    my $chanmodes = [qw(beI k l imnpstaqr)];
    my $statmodes = 'ov';
    my $hashref = { };
    my $count = 0;
    
    while (my $arg = shift @args) {
        if ( ref $arg eq 'ARRAY' ) {
           $chanmodes = $arg;
           next;
        }
        elsif ( ref $arg eq 'HASH' ) {
           $statmodes = join '', keys %{ $arg };
           next;
        }
        elsif ( $arg =~ /^(\+|-)/ or $count == 0 ) {
            my $action = '+';
            for my $char ( split (//,$arg) ) {
                if ($char eq '+' or $char eq '-') {
                   $action = $char;
                }
                else {
                   push @{ $hashref->{modes} }, $action . $char;
                }
                
                if ($char =~ /[$statmodes$chanmodes->[0]$chanmodes->[1]]/) {
                    push @{ $hashref->{args} }, shift @args;
                }
                
                if ($action eq '+' && $char =~ /[$chanmodes->[2]]/) {
                    push @{ $hashref->{args} }, shift @args;
                }
            }
        }
        else {
            push @{ $hashref->{args} }, $arg;
        }
        $count++;
    }

    return $hashref;
}

sub parse_ban_mask {
    my $arg = shift || return;

    $arg =~ s/\x2a{2,}/\x2a/g;
    my @ban;
    my $remainder;
    if ($arg !~ /\x21/ and $arg =~ /\x40/) {
        $remainder = $arg;
    }
    else {
        ($ban[0], $remainder) = split /\x21/, $arg, 2;
    }
    
    $remainder =~ s/\x21//g if defined $remainder;
    @ban[1..2] = split(/\x40/, $remainder, 2) if defined $remainder;
    $ban[2] =~ s/\x40//g if defined $ban[2];
    
    for my $i (1..2) {
        $ban[$i] = '*' if !$ban[$i];
    }
    
    return $ban[0] . '!' . $ban[1] . '@' . $ban[2];
}

sub matches_mask_array {
    my ($masks, $matches, $mapping) = @_;
    
    return if !$masks || !$matches;
    return if ref $masks ne 'ARRAY';
    return if ref $matches ne 'ARRAY';
    my $ref = { };
    
    for my $mask ( @{ $masks } ) {
        for my $match ( @{ $matches } ) {
            if ( matches_mask($mask, $match, $mapping) ) {
                push @{ $ref->{ $mask } }, $match;
            }
        }
    }
    
    return $ref;
}

sub matches_mask {
    my ($mask,$match,$mapping) = @_;

    return if !$mask || !$match;
    $mask = parse_ban_mask($mask);
    $mask =~ s/\x2A+/\x2A/g;

    my $umask = quotemeta u_irc( $mask, $mapping );
    $umask =~ s/\\\*/[\x01-\xFF]{0,}/g;
    $umask =~ s/\\\?/[\x01-\xFF]{1,1}/g;
    $match = u_irc $match, $mapping;

    return 1 if $match =~ /^$umask$/;
    return;
}

sub parse_user {
    my $user = shift || return;
    my ($n, $u, $h) = split /[!@]/, $user;
    return ($n, $u, $h) if wantarray();
    return $n;
}

sub has_color {
    my $string = shift;
    return 1 if $string =~ /[\x03\x04]/;
    return;
}

sub has_formatting {
    my $string = shift;
    return 1 if $string =~/[\x02\x1f\x16\x1d\x11]/;
    return;
}

sub strip_color {
    my $string = shift;
    
    # mIRC colors
    $string =~ s/\x03(?:,\d{1,2}|\d{1,2}(?:,\d{1,2})?)?//g;
    $string =~ s/\x0f//g;
    
    # RGB colors supported by some clients
    $string =~ s/\x04[0-9a-fA-F]{0,6}//ig;
    
    return $string;
}

sub strip_formatting {
    my $string = shift;
    $string =~ s/[\x0f\x02\x1f\x16\x1d\x11]//g;
    return $string;
}

#------------------------------------------------------------------------------
# Subroutine ip_get_version
# Purpose           : Get an IP version
# Params            : IP address
# Returns           : 4, 6, 0(don't know)
sub irc_ip_get_version {
    my $ip = shift || return;

    # If the address does not contain any ':', maybe it's IPv4
    return 4 if $ip !~ /:/ && irc_ip_is_ipv4($ip);

    # Is it IPv6 ?
    return 6 if irc_ip_is_ipv6($ip);

    return;
}

#------------------------------------------------------------------------------
# Subroutine ip_is_ipv4
# Purpose           : Check if an IP address is version 4
# Params            : IP address
# Returns           : 1 (yes) or 0 (no)
sub irc_ip_is_ipv4 {
    my $ip = shift || return;

    # Check for invalid chars
    if ($ip !~ /^[\d\.]+$/) {
        $ERROR = "Invalid chars in IP $ip";
        $ERRNO = 107;
        return;
    }

    if ($ip =~ /^\./) {
        $ERROR = "Invalid IP $ip - starts with a dot";
        $ERRNO = 103;
        return;
    }

    if ($ip =~ /\.$/) {
        $ERROR = "Invalid IP $ip - ends with a dot";
        $ERRNO = 104;
        return;
    }

    # Single Numbers are considered to be IPv4
    return 1 if $ip =~ /^(\d+)$/ && $1 < 256;

    # Count quads
    my $n = ($ip =~ tr/\./\./);

    # IPv4 must have from 1 to 4 quads
    if ($n <= 0 || $n > 4) {
        $ERROR = "Invalid IP address $ip";
        $ERRNO = 105;
        return;
    }

    # Check for empty quads
    if ($ip =~ /\.\./) {
        $ERROR = "Empty quad in IP address $ip";
        $ERRNO = 106;
        return;
    }

    for my $quad (split /\./, $ip) {
        # Check for invalid quads
        if ($quad < 0 || $quad >= 256) {
            $ERROR = "Invalid quad in IP address $ip - $_";
            $ERRNO = 107;
            return;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Subroutine ip_is_ipv6
# Purpose           : Check if an IP address is version 6
# Params            : IP address
# Returns           : 1 (yes) or 0 (no)
sub irc_ip_is_ipv6 {
    my $ip = shift || return;

    # Count octets
    my $n = ($ip =~ tr/:/:/);
    return if ($n <= 0 || $n >= 8);

    # $k is a counter
    my $k;

    for my $octet (split /:/, $ip) {
        $k++;

        # Empty octet ?
        next if $octet eq '';

        # Normal v6 octet ?
        next if $octet =~ /^[a-f\d]{1,4}$/i;

        # Last octet - is it IPv4 ?
        if ($k == $n + 1) {
            next if (ip_is_ipv4($octet));
        }

        $ERROR = "Invalid IP address $ip";
        $ERRNO = 108;
        return;
    }

    # Does the IP address start with : ?
    if ($ip =~ m/^:[^:]/) {
        $ERROR = "Invalid address $ip (starts with :)";
        $ERRNO = 109;
        return;
    }

    # Does the IP address finish with : ?
    if ($ip =~ m/[^:]:$/) {
        $ERROR = "Invalid address $ip (ends with :)";
        $ERRNO = 110;
        return;
    }

    # Does the IP address have more than one '::' pattern ?
    if ($ip =~ s/:(?=:)//g > 1) {
        $ERROR = "Invalid address $ip (More than one :: pattern)";
        $ERRNO = 111;
        return;
    }

    return 1;
}

1;
__END__

=head1 NAME

POE::Component::IRC::Common - provides a set of common functions for the
L<POE::Component::IRC|POE::Component::IRC> suite.

=head1 SYNOPSIS

 use strict;
 use warnings;

 use POE::Component::IRC::Common qw( :ALL );

 my $nickname = '^Lame|BOT[moo]';
 my $uppercase_nick = u_irc( $nickname );
 my $lowercase_nick = l_irc( $nickname );

 my $mode_line = 'ov+b-i Bob sue stalin*!*@*';
 my $hashref = parse_mode_line( $mode_line );

 my $banmask = 'stalin*';
 my $full_banmask = parse_ban_mask( $banmask );

 if ( matches_mask( $full_banmask, 'stalin!joe@kremlin.ru' ) ) {
     print "EEK!";
 }
  
 if ( has_color($message) ) {
    print 'COLOR CODE ALERT!";
 }

 my $results_hashref = matches_mask_array( \@masks, \@items_to_match_against );

 my $nick = parse_user( 'stalin!joe@kremlin.ru' );
 my ($nick, $user, $host) = parse_user( 'stalin!joe@kremlin.ru' );

=head1 DESCRIPTION

POE::Component::IRC::Common provides a set of common functions for the
L<POE::Component::IRC|POE::Component::IRC> suite. There are included functions
for uppercase and lowercase nicknames/channelnames and for parsing mode lines
and ban masks.

=head1 CONSTANTS

Use the following constants to add formatting and mIRC color codes to IRC
messages.

Normal text:

 NORMAL

Formatting:

 BOLD
 UNDERLINE
 REVERSE
 ITALIC
 FIXED

Colors:

 WHITE
 BLACK
 DARK_BLUE
 DARK_GREEN
 RED
 BROWN
 PURPLE
 ORANGE
 YELLOW
 LIGHT_GREEN
 TEAL
 CYAN
 LIGHT_BLUE
 MAGENTA
 DARK_GREY
 LIGHT_GREY

Individual formatting codes can be cancelled with their corresponding constant,
but you can also cancel all of them at once with C<NORMAL>. To cancel the effect
of previous color codes, you must use C<NORMAL>. which of course has the side
effect of cancelling the effect of all previous formatting codes as well.

 $irc->yield('This word is ' . YELLOW . 'yellow' . NORMAL
     . ' while this word is ' . BOLD . 'bold' . BOLD);

 $irc->yield(UNDERLINE . BOLD . 'This sentence is both underlined and bold.'
     . NORMAL);



=head1 FUNCTIONS

=head2 C<u_irc>

Takes one mandatory parameter, a string to convert to IRC uppercase, and one
optional parameter, the casemapping of the ircd ( which can be 'rfc1459',
'strict-rfc1459' or 'ascii'. Default is 'rfc1459' ). Returns the IRC uppercase
equivalent of the passed string.

=head2 C<l_irc>

Takes one mandatory parameter, a string to convert to IRC lowercase, and one
optional parameter, the casemapping of the ircd ( which can be 'rfc1459',
'strict-rfc1459' or 'ascii'. Default is 'rfc1459' ). Returns the IRC lowercase
equivalent of the passed string.

=head2 C<parse_mode_line>

Takes a list representing an IRC mode line. Returns a hashref. If the modeline
couldn't be parsed the hashref will be empty. On success the following keys
will be available in the hashref:

 'modes', an arrayref of normalised modes;
 'args', an arrayref of applicable arguments to the modes;

Example:

 my $hashref = parse_mode_line( 'ov+b-i', 'Bob', 'sue', 'stalin*!*@*' );

 # $hashref will be:
 {
    modes => [ '+o', '+v', '+b', '-i' ],
    args  => [ 'Bob', 'sue', 'stalin*!*@*' ],
 }

=head2 C<parse_ban_mask>

Takes one parameter, a string representing an IRC ban mask. Returns a
normalised full banmask.

Example:

 $fullbanmask = parse_ban_mask( 'stalin*' );

 # $fullbanmask will be: 'stalin*!*@*';

=head2 C<matches_mask>

Takes two parameters, a string representing an IRC mask ( it'll be processed
with parse_ban_mask() to ensure that it is normalised ) and something to match
against the IRC mask, such as a nick!user@hostname string. Returns a true
value if they match, a false value otherwise. Optionally, one may pass the
casemapping (see L<C<u_irc()>|/"u_irc">), as this function uses C<u_irc()>
internally.

=head2 C<matches_mask_array>

Takes two array references, the first being a list of strings representing
IRC masks, the second a list of somethings to test against the masks. Returns
an empty hashref if there are no matches. Otherwise, the keys will be the
masks matched, each value being an arrayref of the strings that matched it.
Optionally, one may pass the casemapping (see L<C<u_irc()>|/"u_irc">), as
this function uses C<u_irc()> internally.

=head2 C<parse_user>

Takes one parameter, a string representing a user in the form
nick!user@hostname. In a scalar context it returns just the nickname.
In a list context it returns a list consisting of the nick, user and hostname,
respectively.

=head2 C<has_color>

Takes one parameter, a string of IRC text. Returns 1 if it contains any IRC
color codes, 0 otherwise. Useful if you want your bot to kick users for
(ab)using colors. :)

=head2 C<has_formatting>

Takes one parameter, a string of IRC text. Returns 1 if it contains any IRC
formatting codes, 0 otherwise.

=head2 C<strip_color>

Takes one paramter, a string of IRC text. Returns the string stripped of all
IRC color codes. Due to the fact that both color and formatting codes can
be cancelled with the same character, this might strip more than you hoped for
if the string contains both color and formatting codes. Stripping both will
always do what you expect it to.

=head2 C<strip_formatting>

Takes one paramter, a string of IRC text. Returns the string stripped of all
IRC formatting codes. Due to the fact that both color and formatting codes can
be cancelled with the same character, this might strip more than you hoped for
if the string contains both color and formatting codes. Stripping both will
always do what you expect it to.

=head2 C<irc_ip_get_version>

Try to guess the IP version of an IP address.

Params: IP address
Returns: 4, 6, 0(unable to determine)

C<$version = ip_get_version ($ip)>

=head2 C<irc_ip_is_ipv4>

Check if an IP address is of type 4.

Params: IP address
Returns: 1 (yes) or 0 (no)

C<ip_is_ipv4($ip) and print "$ip is IPv4";>

=head2 C<irc_ip_is_ipv6>

Check if an IP address is of type 6.

Params: IP address
Returns: 1 (yes) or 0 (no)

 ip_is_ipv6($ip) && print "$ip is IPv6";

=head1 AUTHOR

Chris 'BinGOs' Williams

IP functions are shamelessly 'borrowed' from L<Net::IP|Net::IP> by Manuel
Valente

=head1 SEE ALSO

L<POE::Component::IRC|POE::Component::IRC>

L<Net::IP|Net::IP>

=cut
