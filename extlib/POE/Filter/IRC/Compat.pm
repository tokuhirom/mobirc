package POE::Filter::IRC::Compat;

use strict;
use warnings;
use Carp;
use POE::Filter::IRCD;
use File::Basename qw(fileparse);
use base qw(POE::Filter);

our $VERSION = '6.02';

my %irc_cmds = (
    qr/^\d{3}$/ => sub {
        my ($self, $event, $line) = @_;
        $event->{args}->[0] = _decolon( $line->{prefix} );
        shift @{ $line->{params} };
        if ( $line->{params}->[0] && $line->{params}->[0] =~ /\x20/ ) {
            $event->{args}->[1] = $line->{params}->[0];
        }
        else {
            $event->{args}->[1] = join(' ', ( map { /\x20/ ? ":$_" : $_ } @{ $line->{params} } ) );
        }
        $event->{args}->[2] = $line->{params};
    },
    qr/notice/ => sub {
        my ($self, $event, $line) = @_;

        if ($line->{prefix}) {
            $event->{args} = [
                _decolon( $line->{prefix} ),
                [split /,/, $line->{params}->[0]],
                ($self->{identifymsg}
                    ? _split_idmsg($line->{params}->[1])
                    : $line->{params}->[1]
                ),
            ];
        }
        else {
            $event->{name} = 'snotice';
            $event->{args}->[0] = $line->{params}->[1];
        }
    },
    qr/privmsg/ => sub {
        my ($self, $event, $line) = @_;
        if ( grep { index( $line->{params}->[0], $_ ) >= 0 } @{ $self->{chantypes} } ) {
            $event->{args} = [
                _decolon( $line->{prefix} ),
                [split /,/, $line->{params}->[0]],
                ($self->{identifymsg}
                    ? _split_idmsg($line->{params}->[1])
                    : $line->{params}->[1]
                ),
            ];
            $event->{name} = 'public';
        }
        else {
            $event->{args} = [
                _decolon( $line->{prefix} ),
                [split /,/, $line->{params}->[0]],
                ($self->{identifymsg}
                    ? _split_idmsg($line->{params}->[1])
                    : $line->{params}->[1]
                ),
            ];
            $event->{name} = 'msg';
        }
    },
    qr/invite/ => sub {
        my ($self, $event, $line) = @_;
        shift( @{ $line->{params} } );
        unshift( @{ $line->{params} }, _decolon( $line->{prefix} || '' ) ) if $line->{prefix};
        $event->{args} = $line->{params};
    },
);

# the magic cookie jar
my %dcc_types = (
    qr/CHAT|SEND/ => sub {
        my ($nick, $type, $args) = @_;
        my ($file, $addr, $port, $size);
        return if !(($file, $addr, $port, $size) = $args =~ /^(".+"|[^ ]+) +(\d+) +(\d+)(?: +(\d+))?/);
        
        if ($file =~ s/^"//) {
            $file =~ s/"$//;
            $file =~ s/\\"/"/g;
        }
        $file = fileparse($file);
        
        return (
            $port,
            {
                nick => $nick,
                type => $type,
                file => $file,
                size => $size,
                addr => $addr,
                port => $port,
            },
            $file,
            $size,
            $addr,
        );
    },
    qr/ACCEPT|RESUME/ => sub {
        my ($nick, $type, $args) = @_;
        my ($file, $port, $position);
        return if !(($file, $port, $position) = $args =~ /^(".+"|[^ ]+) +(\d+) +(\d+)/);

        $file =~ s/^"|"$//g;
        $file = fileparse($file);

        return (
            $port,
            {
                nick => $nick,
                type => $type,
                file => $file,
                size => $position,
                port => $port,
            },
            $file,
            $position,
        );
    },
);

sub new {
    my ($package, %self) = @_;
    
    $self{lc $_} = delete $self{$_} for keys %self;
    $self{BUFFER} = [ ];
    $self{_ircd} = POE::Filter::IRCD->new();
    $self{chantypes} = [ '#', '&' ] if ref $self{chantypes} ne 'ARRAY';
  
    return bless \%self, $package;
}

sub clone {
    my $self = shift;
    my $nself = { };
    $nself->{$_} = $self->{$_} for keys %{ $self };
    $nself->{BUFFER} = [ ];
    return bless $nself, ref $self;
}

# Set/clear the 'debug' flag.
sub debug {
    my ($self, $flag) = @_;
    if (defined $flag) {
        $self->{debug} = $flag;
        $self->{_ircd}->debug($flag);
    }
    return $self->{debug};
}

sub chantypes {
    my ($self, $ref) = @_;
    return if ref $ref ne 'ARRAY' || !@{ $ref };
    $self->{chantypes} = $ref;
    return 1;
}

sub identifymsg {
    my ($self, $switch) = @_;
    $self->{identifymsg} = $switch;
    return;
}

sub _split_idmsg {
    my ($line) = @_;
    my ($identified, $msg) = split //, $line, 2;
    $identified = $identified eq '+' ? 1 : 0;
    return $msg, $identified;
}

sub get_one {
    my ($self) = @_;
    my $line = shift @{ $self->{BUFFER} } or return [ ];

    if (ref $line ne 'HASH' || !$line->{command} || !$line->{params}) {
        warn "Received line '$line' that is not IRC protocol\n" if $self->{debug};
        return [ ];
    }
    
    if ($line->{command} =~ /^PRIVMSG|NOTICE$/ && $line->{params}->[1] =~ tr/\001//) {
        return $self->_get_ctcp($line);
    }
    
    my $event = {
        name     => lc $line->{command},
        raw_line => $line->{raw_line},
    };

    for my $cmd (keys %irc_cmds) {
        if ($event->{name} =~ $cmd) {
            $irc_cmds{$cmd}->($self, $event, $line);
            return [ $event ];
        }
    }
    
    # default
    unshift( @{ $line->{params} }, _decolon( $line->{prefix} || '' ) ) if $line->{prefix};
    $event->{args} = $line->{params};
    return [ $event ];
}

sub get_one_start {
    my ($self, $lines) = @_;
    push @{ $self->{BUFFER} }, @$lines;
    return;
}

sub put {
    my ($self, $lineref) = @_;
    my $quoted = [ ];
    push @$quoted, _ctcp_quote($_) for @$lineref;
    return $quoted;
}

# Properly CTCP-quotes a message. Whoop.
sub _ctcp_quote {
    my ($line) = @_;

    $line = _low_quote( $line );
    #$line =~ s/\\/\\\\/g;
    $line =~ s/\001/\\a/g;

    return "\001$line\001";
}

# Splits a message into CTCP and text chunks. This is gross. Most of
# this is also stolen from Net::IRC, but I (fimm) wrote that too, so it's
# used with permission. ;-)
sub _ctcp_dequote {
    my ($msg) = @_;
    my (@chunks, $ctcp, $text);

    # CHUNG! CHUNG! CHUNG!

    if (!defined $msg) {
        croak 'Not enough arguments to POE::Filter::IRC::Compat->_ctcp_dequote';
    }

    # Strip out any low-level quoting in the text.
    $msg = _low_dequote( $msg );

    # Filter misplaced \001s before processing... (Thanks, tchrist!)
    substr($msg, rindex($msg, "\001"), 1, '\\a')
        if ($msg =~ tr/\001//) % 2 != 0;

    return if $msg !~ tr/\001//;

    @chunks = split /\001/, $msg;
    shift @chunks if !length $chunks[0]; # FIXME: Is this safe?

    for (@chunks) {
        # Dequote unnecessarily quoted chars, and convert escaped \'s and ^A's.
        s/\\([^\\a])/$1/g;
        s/\\\\/\\/g;
        s/\\a/\001/g;
    }

    # If the line begins with a control-A, the first chunk is a CTCP
    # message. Otherwise, it starts with text and alternates with CTCP
    # messages. Really stupid protocol.
    if ($msg =~ /^\001/) {
        push @$ctcp, shift @chunks;
    }

    while (@chunks) {
        push @$text, shift @chunks;
        push @$ctcp, shift @chunks if @chunks;
    }

    return ($ctcp, $text);
}

sub _decolon {
    my ($line) = @_;

    $line =~ s/^://;
    return $line;
}

## no critic (Subroutines::ProhibitExcessComplexity)
sub _get_ctcp {
    my ($self, $line) = @_;

    # Is this a CTCP request or reply?
    my $ctcp_type = $line->{command} eq 'PRIVMSG' ? 'ctcp' : 'ctcpreply';
    
    # CAPAP IDENTIFY-MSG is only applied to ACTIONs
    my ($msg, $identified) = ($line->{params}->[1], undef);
    ($msg, $identified) = _split_idmsg($msg) if $self->{identifymsg} && $msg =~ /^.ACTION/;
    
    my ($ctcp, $text) = _ctcp_dequote($msg);
    my $nick = defined $line->{prefix} ? (split /!/, $line->{prefix})[0] : undef;

    my $events = [ ];
    my ($name, $args);
    CTCP: for my $string (@$ctcp) {
        if (!(($name, $args) = $string =~ /^(\w+)(?: +(.*))?/)) {
            defined $nick
                ? do { warn "Received malformed CTCP message from $nick: $string\n" if $self->{debug} }
                : do { warn "Trying to send malformed CTCP message: $string\n" if $self->{debug} }
            ;
            last CTCP;
        }
            
        if (lc $name eq 'dcc') {
            my ($dcc_type, $rest);
            
            if (!(($dcc_type, $rest) = $args =~ /^(\w+) +(.+)/)) {
                defined $nick
                    ? do { warn "Received malformed DCC request from $nick: $args\n" if $self->{debug} }
                    : do { warn "Trying to send malformed DCC request: $args\n" if $self->{debug} }
                ;
                last CTCP;

            }
            $dcc_type = uc $dcc_type;

            my ($handler) = grep { $dcc_type =~ /$_/ } keys %dcc_types;
            if (!$handler) {
                warn "Unhandled DCC $dcc_type request: $rest\n" if $self->{debug};
                last CTCP;
            }

            my @dcc_args = $dcc_types{$handler}->($nick, $dcc_type, $rest);
            if (!@dcc_args) {
                defined $nick
                    ? do { warn "Received malformed DCC $dcc_type request from $nick: $rest\n" if $self->{debug} }
                    : do { warn "Trying to send malformed DCC $dcc_type request: $rest\n" if $self->{debug} }
                ;
                last CTCP;
            }

            push @$events, {
                name => 'dcc_request',
                args => [
                    $line->{prefix},
                    $dcc_type,
                    @dcc_args,
                ],
                raw_line => $line->{raw_line},
            };
        }
        else {
            push @$events, {
                name => $ctcp_type . '_' . lc $name,
                args => [
                    $line->{prefix},
                    [split /,/, $line->{params}->[0]],
                    (defined $args ? $args : ''),
                    (defined $identified ? $identified : () ),
                ],
                raw_line => $line->{raw_line},
            };
        }
    }

    if ($text && @$text) {
        my $what;
        ($what) = $line->{raw_line} =~ /^(:[^ ]+ +\w+ +[^ ]+ +)/
            or warn "What the heck? '".$line->{raw_line}."'\n" if $self->{debug};
        $text = (defined $what ? $what : '') . ':' . join '', @$text;
        $text =~ s/\cP/^P/g;
        warn "CTCP: $text\n" if $self->{debug};
        push @$events, @{ $self->{_ircd}->get([$text]) };
    }
    
    return $events;
}

# Quotes a string in a low-level, protocol-safe, utterly brain-dead
# fashion. Returns the quoted string.
sub _low_quote {
    my ($line) = @_;
    my %enquote = ("\012" => 'n', "\015" => 'r', "\0" => '0', "\cP" => "\cP");

    if (!defined $line) {
        croak 'Not enough arguments to POE::Filter::IRC::Compat->_low_quote';
    }

    if ($line =~ tr/[\012\015\0\cP]//) { # quote \n, \r, ^P, and \0.
        $line =~ s/([\012\015\0\cP])/\cP$enquote{$1}/g;
    }

    return $line;
}

# Does low-level dequoting on CTCP messages. I hate this protocol.
# Yes, I copied this whole section out of Net::IRC.
sub _low_dequote {
    my ($line) = @_;
    my %dequote = (n => "\012", r => "\015", 0 => "\0", "\cP" => "\cP");

    if (!defined $line) {
        croak 'Not enough arguments to POE::Filter::IRC::Compat->_low_dequote';
    }

    # dequote \n, \r, ^P, and \0.
    # Thanks to Abigail (abigail@foad.org) for this clever bit.
    if ($line =~ tr/\cP//) {
        $line =~ s/\cP([nr0\cP])/$dequote{$1}/g;
    }

    return $line;
}

1;
__END__

=head1 NAME

POE::Filter::IRC::Compat - A filter which converts L<POE::Filter::IRCD|POE::Filter::IRCD>
output into L<POE::Component::IRC|POE::Component::IRC> events

=head1 SYNOPSIS

 my $filter = POE::Filter::IRC::Compat->new();
 my @events = @{ $filter->get( [ @lines ] ) };
 my @msgs = @{ $filter->put( [ @messages ] ) };

=head1 DESCRIPTION

POE::Filter::IRC::Compat is a L<POE::Filter|POE::Filter> that converts
L<POE::Filter::IRCD|POE::Filter::IRCD> output into the L<POE::Component::IRC|POE::Component::IRC>
compatible event references. Basically a hack, so I could replace
L<POE::Filter::IRC|POE::Filter::IRC> with something that was more
generic.

Among other things, it converts normal text into thoroughly CTCP-quoted
messages, and transmogrifies CTCP-quoted messages into their normal,
sane components. Rather what you'd expect a filter to do.

A note: the CTCP protocol sucks bollocks. If I ever meet the fellow who
came up with it, I'll shave their head and tattoo obscenities on it.
Just read the "specification" (F<docs/ctcpspec.html> in this distribution)
and you'll hopefully see what I mean. Quote this, quote that, quote this
again, all in different and weird ways... and who the hell needs to send
mixed CTCP and text messages? WTF? It looks like it's practically complexity
for complexity's sake -- and don't even get me started on the design of the
DCC protocol! Anyhow, enough ranting. Onto the rest of the docs...

=head1 METHODS

=head2 C<new>

Returns a POE::Filter::IRC::Compat object. Takes no arguments.

=head2 C<clone>

Makes a copy of the filter, and clears the copy's buffer.

=head2 C<get>

Takes an arrayref of L<POE::Filter::IRCD> hashrefs and produces an arrayref of
L<POE::Component::IRC|POE::Component::IRC> compatible event hashrefs. Yay.

=head2 C<get_one_start>, C<get_one>

These perform a similar function as C<get> but enable the filter to work with
L<POE::Filter::Stackable|POE::Filter::Stackable>.

=head2 C<put>

Takes an array reference of CTCP messages to be properly quoted. This
doesn't support CTCPs embedded in normal messages, which is a
brain-dead hack in the protocol, so do it yourself if you really need
it. Returns an array reference of the quoted lines for sending.

=head2 C<debug>

Takes an optinal true/false value which enables/disables debugging
accordingly. Returns the debug status.

=head2 C<chantypes>

Takes an arrayref of possible channel prefix indicators.

=head2 C<identifymsg>

Takes a boolean to turn on/off the support for CAPAB IDENTIFY-MSG.

=head1 AUTHOR

Chris 'BinGOs' Williams

=head1 SEE ALSO

L<POE::Filter::IRCD|POE::Filter::IRCD>

L<POE::Filter|POE::Filter>

L<POE::Filter::Stackable|POE::Filter::Stackable>

=cut
