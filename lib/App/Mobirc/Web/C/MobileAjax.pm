package App::Mobirc::Web::C::MobileAjax;
use Moose;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/to_json/;
use URI::Escape qw/uri_escape/;

sub dispatch_index {
    my ($class, $req) = @_;

    render_td(
        $req,
        'mobile-ajax/index' => (
            mobile_agent => $req->mobile_agent,
            docroot =>
              ( App::Mobirc->context->{config}->{httpd}->{root} || '/' ),
            channels => [ server->channels ],
        )
    );
}

sub dispatch_channel {
    my ($class, $req) = @_;
    my $channel_name = $req->query_params->{channel} or die 'missing channel name';
    my $channel = server->get_channel($channel_name);

    my $body;
    if (@{$channel->message_log}) {
        my $meth = $req->query_params->{recent} ? 'recent_log' : 'message_log';
        my $json = to_json(
            [
                map {
                    App::Mobirc::Web::View->show( 'irc_message', $_, irc_nick )
                  } reverse $channel->$meth
            ]
        );
        $body = encode($req->mobile_agent->encoding, "Mobirc.callbackChannel($json);" );

        $channel->clear_unread();
    } else {
        $body = '';
    }
    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain; charset=UTF-8',
        body         => $body,
    );
}

sub post_dispatch_channel {
    my ( $class, $req, $args) = @_;
    my $channel = $req->params->{'channel'};
    my $message = $req->params->{'msg'};

    context->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain; charset=UTF-8',
        body         => 'ok',
    );
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

