package DB;
sub called_args {
	my ($level) = @_;
	my @foo = caller( ( $level || 0 ) + 3 );
	wantarray ? @DB::args : \@DB::args;
}

package Devel::Caller::Perl;
use DB;
$Devel::Caller::Perl::VERSION   = '1.4';
sub import {
    *{(caller)[0].'::called_args'} = \&called_args
      if $_[1] eq 'called_args';
}
sub called_args { &DB::called_args }

1;

__END__

=pod

=head1 NAME

Devel::Caller::Perl - Perl only implementation.

=head1 SYNOPSIS

 use Devel::Caller::Perl qw[called_args];
 
 sub permute_args {
   my @args = @_;
   my @caller_args = called_args( 0 );
   
   my %caller_args =
     map { $_ => $caller_args[$_] } 0 .. $#caller_args;
   
   return \%caller_args;
 }

 sub dodad {
   my $args = permute_args;

   print $args->{0};
   # ...
 }

=head1 ABSTRACT

This module allows a method to get at arguments passed to subroutines
higher up in the call stack.

=head1 DESCRIPTION

=head2 FUNCTIONS

=head3 called_args [LEVEL]

C<called_args> returns the arguments to the subroutine at LEVEL in
the call stack.  If no level is specified, 0 (zero) is assumed, that
being our caller.  If a list is expected, it will be returned.  When a
scalar is expected, a list reference will be returned.

If you want the number of arguments passed to the subroutine at LEVEL,
there's nothing stopping you from getting it from C<caller>.

 my $number = (caller $level)[4];

=head1 AUTHOR

Casey West <F<casey@geeknest.com>>

=head1 THANKS

Rocco Caputo -- Much help with code and overall inspiration.

=head1 COPYRIGHT

Copyright (c) 2003 Casey West.  All rights reserved.  This
program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>, L<Devel::Caller>, L<DB>, L<perldebguts>.

=cut
