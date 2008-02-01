package App::Mobirc::Message;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/channel who body class time/);

sub new {
    my $class = shift;
    bless {'time' => time(), @_}, $class;
}

1;
