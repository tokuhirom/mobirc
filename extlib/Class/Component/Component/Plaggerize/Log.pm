package Class::Component::Component::Plaggerize::Log;
use strict;
use warnings;

use Encode ();
my $TERM_ANSICOLOR_ENABLED = eval { use Term::ANSIColor; 1; };


my %levels = (
    debug => 1,
    warn  => 2,
    info  => 3,
    error => 4,
);

sub setup_config {
    my $class = shift;
    my $config = $class->NEXT( setup_config => @_ );

    $config->{global} = {} unless $config->{global};
    $config->{global}->{log} = {} unless $config->{global}->{log};
    $config->{global}->{log}->{level} = 'debug' unless $config->{global}->{log}->{level};

    %levels = %{ $config->{global}->{log}->{levels} } if ref($config->{global}->{log}->{levels}) eq 'HASH';

    $config;
}

sub log {
    my ($self, $level, $msg, %opt) = @_;
    $self->NEXT( log => @_ );

    my $conf      = $self->conf->{global}->{log};
    return unless ( $levels{$level} || 0 ) >= ( $levels{$conf->{level}} || 0 );

    # hack to get the original caller as Plugin
    my $caller = $opt{caller};
    unless ($caller) {
        my $i = 0;
        while (my $c = caller($i++)) {
            last if $c !~ /Plugin/;
            $caller = $c;
        }
        $caller ||= caller(3);
    }

    my $fh        = defined($conf->{fh}) ? $conf->{fh} : \*STDOUT;
    my $ansicolor = defined($conf->{ansicolor}) ? $conf->{ansicolor} : 'red';

    chomp($msg);
    if ( $conf->{encoding} ) {
        $msg = Encode::decode_utf8($msg) unless utf8::is_utf8($msg);
        $msg = Encode::encode( $conf->{encoding}, $msg );
    }

    local $| = 1;
    print $fh Term::ANSIColor::color($ansicolor) if $ansicolor && $TERM_ANSICOLOR_ENABLED;
    print $fh "$caller [$level] $msg\n";
    print $fh Term::ANSIColor::color("reset") if $ansicolor && $TERM_ANSICOLOR_ENABLED;
}

1;
