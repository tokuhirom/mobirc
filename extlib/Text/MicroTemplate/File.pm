package Text::MicroTemplate::File;

use strict;
use warnings;
use Text::MicroTemplate;

use Carp qw(croak);

our @ISA = qw(Text::MicroTemplate);

sub new {
    my $klass = shift;
    my $self = $klass->SUPER::new(@_);
    $self->{open_layer}   ||= ':utf8';
    $self->{include_path} ||= [ '.' ];
    unless (ref $self->{include_path}) {
        $self->{include_path} = [ $self->{include_path} ];
    }
    $self->{use_cache} ||= 0;
    $self->{cache} = {};  # file => { mtime, sub }
    $self;
}

sub open_layer {
    my $self = shift;
    $self->{open_layer} = $_[0]
        if @_;
    $self->{open_layer};
}

sub use_cache {
    my $self = shift;
    $self->{use_cache} = $_[0]
        if @_;
    $self->{use_cache};
}

sub build_file {
    my ($self, $file) = @_;
    # return cached entry
    if ($self->{use_cache} == 2) {
        if (my $e = $self->{cache}->{$file}) {
            return $e->[1];
        }
    }
    # iterate
    foreach my $path (@{$self->{include_path}}) {
        my $filepath = $path . '/' . $file;
        if (my @st = stat $filepath) {
            if (my $e = $self->{cache}->{$file}) {
                return $e->[1]
                    if $st[9] == $e->[0];
            }
            open my $fh, "<$self->{open_layer}", $filepath
                or croak "failed to open:$filepath:$!";
            my $src = do { local $/; join '', <$fh> };
            close $fh;
            $self->parse($src);
            $self->{cache}->{$file} = [
                $st[9],
                my $f = $self->build(),
            ];
            return $f;
        }
    }
    die "could not find template file: $file\n";
}

sub render_file {
    my $self = shift;
    my $file = shift;
    $self->build_file($file)->(@_);
}

sub wrapper_file {
    my $self = shift;
    my $file = shift;
    my @args = @_;
    my $mtref = do {
        no strict 'refs';
        ${"$self->{package_name}::_MTREF"};
    };
    my $before = $$mtref;
    $$mtref = '';
    return sub {
        my $inner_func = shift;
        $inner_func->(@_);
        $$mtref =
            $before . $self->render_file($file, Text::MicroTemplate::encoded_string($$mtref), @args)->as_string;
    }
}

1;
__END__

=head1 NAME

Text::MicroTemplate::File - a file-based template manager

=head1 SYNOPSIS

    use Text::MicroTemplate::File;

    our $mtf = Text::MicroTemplate->new(
        include_path => [ $path1, $path2, ... ],
        use_cache    => 1,
    );

    # render
    $mtf->render_file('template.file', $arg1, $arg2, ...);

=head1 DESCRIPTION

Text::MicroTemplate::File is a file-based template manager for L<Text::MicroTemplate>.

=head1 PROPERTIES

Text::MicroTemplate provides OO-style interface with following properties.

=head2 cache

cache mode (0: no cache (default), 1: cache with update check, 2: cache but do not check updates)

=head2 open_layer

layer passed to L<open> (default: ":utf8")

=head2 package_name

package under where template files are compiled (deafult: "main")

=head1 METHODS

=head2 build_file($file)

Returns a subref that renders given template file.

=head2 render_file($file, @args)

Renders the template file with given arguments.

=head1 SEE ALSO

L<Text::MicroTemplate>

=head1 AUTHOR

Kazuho Oku E<lt>kazuhooku gmail.comE<gt>

=head1 LICENSE

This program is free software, you can redistribute it and/or modify it under the same terms as Perl 5.10.

=cut
