package Router::Simple::Declare;
use strict;
use warnings;
use parent 'Exporter';
use Router::Simple;
use Carp ();

our @EXPORT = qw/router connect submapper/;

our $_ROUTER;

sub router (&) {
    local $_ROUTER = Router::Simple->new();
    $_[0]->();
    $_ROUTER;
}

BEGIN {
    no strict 'refs';
    for my $meth (qw/connect submapper/) {
        *{$meth} = sub {
            local $Carp::CarpLevel = $Carp::CarpLevel + 1;
            $_ROUTER->$meth(@_);
        };
    }
}

1;
__END__

=head1 NAME

Router::Simple::Declare - declarative interface for Router::Simple

=head1 SYNOPSIS

    use Router::Simple::Declare;

    my $router = router {
        connect '/{controller}/{action}/{id}';

        submapper('/account', {controller => 'Account'})
            ->connect('/login', {action => 'login'})
            ->connect('/logout', {action => 'logout'});
    };
    $router->match('/entry/show/3');

=head1 DESCRIPTION

Easy way to declare router object.

=head1 USAGE

look the SYNOPSIS.see L<Router::Simple> for more details.

=head1 FUNCTIONS

=over 4

=item router

=item connect

=item submapper

=back

=head1 SEE ALSO

L<Router::Simple>

=cut
