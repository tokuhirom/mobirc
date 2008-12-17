package App::Mobirc::Web::C::MobileAjax;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;
use JSON qw/to_json/;

sub dispatch_index {
    render_td( );
}

sub dispatch_channel {
    my $channel_name = param('channel') or die 'missing channel name';
    my $channel = server->get_channel($channel_name);

    my $body;
    if (@{$channel->message_log}) {
        my $meth = param('recent') ? 'recent_log' : 'message_log';
        my $json = to_json(
            [
                map {
                    render_irc_message( $_ )
                  } reverse $channel->$meth
            ]
        );
        $body = encode_utf8("Mobirc.callbackChannel($json);" );

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
    my $channel = param('channel');
    my $message = param('msg');

    context->get_channel($channel)->post_command($message);

    HTTP::Engine::Response->new(
        status       => 200,
        content_type => 'text/plain; charset=UTF-8',
        body         => 'ok',
    );
}

1;
__END__

=head1 AUTHORS

mayuki-t

Tokuhiro Matsuno

