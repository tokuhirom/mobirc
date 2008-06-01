package App::Mobirc::Plugin::MessageBodyFilter::IRCColor;
use strict;
use MooseX::Plaggerize::Plugin;

has no_decorate => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

hook message_body_filter => sub {
    my ( $self, $global_context, $text ) = @_;

    return _decorate_irc_color($text, $self->no_decorate);
};

sub _decorate_irc_color {
    my ($src, $no_decorate) = @_;

    if ( $src !~ /[\x02\x03\x0f\x16\x1f]/ ) {
        # skip without colorcode
        return $src;
    }

    my $colorized     = '';
    my %default_state = (
        bold      => 0,
        inverse   => 0,
        underline => 0,
    );
    my %state       = (%default_state);
    my $oldstyle    = '';
    my $output_span = sub { ''; };
    unless ( $no_decorate ) {
        $output_span = sub {
            my $style = '';
            if ( $state{bold} ) {
                $style .= "font-weight:bold;";
            }
            if ( $state{underline} ) {
                $style .= "text-decoration:underline;";
            }
            if ( $state{inverse} ) {
    
                # xxx not sure this is correct
                @state{qw(color bgcolor)} = @state{qw(bgcolor color)};
    
                # XXX too bad
                delete $state{inverse};
            }
            if ( $state{color} ) {
                if ( my $color = _irc_color( $state{color} ) ) {
                    $style .= "color:$color;";
                }
            }
            if ( $state{bgcolor} ) {
                if ( my $color = _irc_color( $state{bgcolor} ) ) {
                    $style .= "background-color:$color;";
                }
            }
            my $output = '';
            if ( $oldstyle ne $style ) {
                if ($oldstyle) {
                    $output .= '</span>';
                }
                if ($style) {
                    $output .= qq{<span style="$style">};
                }
            }
            $oldstyle = $style;
            $output;
        };
    }

    while ($src) {
        if ( $src =~ s/^\x02// ) {
            $state{bold} = !$state{bold};
        }
        elsif ( $src =~ s/^\x03(?:(\d{1,2})(?:,(\d{1,2}))?)?// ) {

            # if it has bad color specifiers, just ignore it.
            $state{color}   = int($1) if $1;
            $state{bgcolor} = int($2) if $2;
        }
        elsif ( $src =~ s/^\x0f// ) {
            %state = (%default_state);
        }
        elsif ( $src =~ s/^\x16// ) {
            $state{inverse} = !$state{inverse};
        }
        elsif ( $src =~ s/^\x1f// ) {
            $state{underline} = !$state{underline};
        }
        elsif ( $src =~ s/^([^\x02\x03\x16\x1f\x0f]+)// ) {
            $colorized .= $output_span->() . $1;
        }
        else {
            if ( $src =~ s/^(.*)$// ) {
                # garbase
                use Data::Dumper;
                # DEBUG "garbage: " . Dumper($1);
                $colorized .= $output_span->() . $1;
            }
            last;
        }
    }
    %state = (%default_state);
    $colorized .= $output_span->();

    return $colorized;
}

my %color_table;

BEGIN {
    %color_table = (
        0  => [qw(white)],
        1  => [qw(black)],
        2  => [qw(blue         navy)],
        3  => [qw(green)],
        4  => [qw(red)],
        5  => [qw(brown        maroon)],
        6  => [qw(purple)],
        7  => [qw(orange       olive)],
        8  => [qw(yellow)],
        9  => [qw(lightgreen   lime)],
        10 => [qw(teal)],
        11 => [qw(lightcyan    cyan aqua)],
        12 => [qw(lightblue    royal)],
        13 => [qw(pink         lightpurple  fuchsia)],
        14 => [qw(grey)],
        15 => [qw(lightgrey    silver)],
    );
}

sub _irc_color {
    my $num = shift;
    $color_table{$num}->[0];
}

1;
