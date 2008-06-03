package App::Mobirc::Web::C::MobileAjax;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/to_json/;
use URI::Escape qw/uri_escape/;

sub dispatch_index {
    my ($class, $c) = @_;

    render_td(
        $c,
        'mobile-ajax/index' => (
            mobile_agent => $c->req->mobile_agent,
            docroot =>
              ( App::Mobirc->context->{config}->{httpd}->{root} || '/' ),
            channels => [ server->channels ],
        )
    );
}

sub dispatch_channel {
    my ($class, $c) = @_;
    my $channel_name = $c->req->query_params->{channel} or die 'missing channel name';
    my $channel = server->get_channel($channel_name);

    if (@{$channel->message_log}) {
        my $meth = $c->req->query_params->{recent} ? 'recent_log' : 'message_log';
        my $json = to_json(
            [
                map {
                    App::Mobirc::Web::View->show( 'irc_message', $_, irc_nick )
                  } reverse $channel->$meth
            ]
        );
        $c->res->body( "Mobirc.callbackChannel($json);");

        $channel->clear_unread();
    } else {
        $c->res->body('');
    }
}

sub post_dispatch_channel {
    my ( $class, $c, $args) = @_;
    my $channel = $c->req->params->{'channel'};
    my $message = $c->req->params->{'msg'};

    context->get_channel($channel)->post_command($message);

    $c->res->body('ok');
}

#   sub dispatch_recent {
#       my ($class, $c) = @_;
#       $c->res->body('');
#   }

1;
__END__

=head1 AUTHORS

mayuki-t

Tokuhiro Matsuno

