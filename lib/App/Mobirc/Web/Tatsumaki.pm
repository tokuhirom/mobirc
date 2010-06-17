use strict;
use warnings;
use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::MessageQueue;

package App::Mobirc::Web::Tatsumaki;

my $app = Tatsumaki::Application->new(
    [ "/tatsumaki/poll" => 'App::Mobirc::Web::Tatsumaki::PollHandler', ]
);

sub handler { $app }

package App::Mobirc::Web::Tatsumaki::PollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my ( $self, ) = @_;

    my $mq        = Tatsumaki::MessageQueue->instance('mobirc');
    my $client_id = $self->request->param('client_id')
      or Tatsumaki::Error::HTTP->throw( 500, "'client_id' needed" );
    $client_id = rand(1) if $client_id eq 'dummy';    # for benchmarking stuff
    $mq->poll_once( $client_id, sub { $self->on_new_event(@_) } );
}

sub on_new_event {
    my ( $self, @events ) = @_;
    $self->write( \@events );
    $self->finish;
}

1;
