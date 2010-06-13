package Router::Simple::SubMapper;
use strict;
use warnings;
use Scalar::Util qw/weaken/;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    weaken($self->{parent});
    $self;
}

sub connect {
    my ($self, $pattern, $dest, $opt) = @_;
    $pattern = $self->{pattern}.$pattern if $self->{pattern};
    $dest ||= +{};
    $opt ||= +{};

    $self->{parent}->connect(
        $pattern,
        { %{ $self->{dest} }, %$dest },
        { %{ $self->{opt} },  %$opt }
    );

    $self; # chained method
}

1;
__END__

=head1 NAME

Router::Simple::SubMapper - submapper

=head1 SYNOPSIS

    use Router::Simple;

    my $router = Router::Simple->new();
    my $s = $router->submapper('/entry/{id}', {controller => 'Entry'});
    $s->connect('/edit' => {action => 'edit'})
      ->connect('/show' => {action => 'show'});

=head1 DESCRIPTION

Router::Simple::SubMapper is sub-mapper for L<Router::Simple>.
This class provides shorthand to create routes, that have common parts.

=head1 METHODS

=over 4

=item my $submapper = $router->submapper(%args);

Do not call this method directly.You should create new instance from $router->submapper(%args).

=item $submapper->connect(@args)

This method creates new route to parent $router with @args and arguments of ->submapper().

This method returns $submapper itself for method-chain.

=back

=head1 SEE ALSO

L<Router::Simple>

