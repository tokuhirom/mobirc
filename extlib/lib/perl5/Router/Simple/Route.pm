package Router::Simple::Route;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/name dest on_match method host pattern/);

sub new {
    my $class = shift;

    # connect([$name, ]$pattern[, \%dest[, \%opt]])
    if (@_ == 1 || ref $_[1]) {
        unshift(@_, undef);
    }

    my ($name, $pattern, $dest, $opt) = @_;
    Carp::croak("missing pattern") unless $pattern;
    my $row = +{
        name     => $name,
        dest     => $dest,
        on_match => $opt->{on_match},
    };
    if (my $method = $opt->{method}) {
        $method = [$method] unless ref $method;
        $row->{method} = $method;

        my $method_re = join '|', @{$method};
        $row->{method_re} = qr{^(?:$method_re)$};
    }
    if (my $host = $opt->{host}) {
        $row->{host} = $host;
        $row->{host_re} = ref $host ? $host : qr(^\Q$host\E$);
    }

    $row->{pattern} = $pattern;

    # compile pattern
    my @capture;
    $row->{pattern_re} = do {
        if (ref $pattern) {
            $row->{_regexp_capture} = 1;
            $pattern;
        } else {
            $pattern =~ s!
                \{((?:\{[0-9,]+\}|[^{}]+)+)\} | # /blog/{year:\d{4}}
                :([A-Za-z0-9_]+)              | # /blog/:year
                (\*)                          | # /blog/*/*
                ([^{:*]+)                       # normal string
            !
                if ($1) {
                    my ($name, $pattern) = split /:/, $1;
                    push @capture, $name;
                    $pattern ? "($pattern)" : "([^/]+)";
                } elsif ($2) {
                    push @capture, $2;
                    "([^/]+)";
                } elsif ($3) {
                    push @capture, '__splat__';
                    "(.+)";
                } else {
                    quotemeta($4);
                }
            !gex;
            qr{^$pattern$};
        }
    };
    $row->{capture} = \@capture;

    return bless $row, $class;
}

sub match {
    my ($self, $env) = @_;

    if ($self->{host_re}) {
        unless ($env->{HTTP_HOST} =~ $self->{host_re}) {
            return undef;
        }
    }
    if ($self->{method_re}) {
        unless (($env->{REQUEST_METHOD} || '') =~ $self->{method_re}) {
            return undef;
        }
    }
    if (my @captured = ($env->{PATH_INFO} =~ $self->{pattern_re})) {
        my %args;
        my @splat;
        if ($self->{_regexp_capture}) {
            push @splat, @captured;
        } else {
            for my $i (0..@{$self->{capture}}-1) {
                if ($self->{capture}->[$i] eq '__splat__') {
                    push @splat, $captured[$i];
                } else {
                    $args{$self->{capture}->[$i]} = $captured[$i];
                }
            }
        }
        my $match = +{
            %{$self->{dest}},
            %args,
            ( @splat ? ( splat => \@splat ) : () ),
        };
        if ($self->{on_match}) {
            my $ret = $self->{on_match}->($env, $match);
            return undef unless $ret;
        }
        return $match;
    }
    return undef;
}

1;
__END__

=head1 NAME

Router::Simple::Route - route object

=head1 DESCRIPTION

This class represents route.

=head1 ATTRIBUTES

This class provides following attributes.

=over 4

=item name

=item dest

=item on_match

=item method

=item host

=item pattern

=back

=head1 SEE ALSO

L<Router::Simple>

