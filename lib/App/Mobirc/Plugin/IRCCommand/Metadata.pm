package App::Mobirc::Plugin::IRCCommand::Metadata;
use strict;
use App::Mobirc::Plugin;
use App::Mobirc::Util;
use Encode;
use JSON;

hook on_irc_notice => sub {
	my ($self, $global_context, $poe, $who, $channel_name, $msg) = @_;

	if ($who eq "metadata") {
		$channel_name = $channel_name->[0];
		$channel_name = normalize_channel_name($channel_name);

		my $channel = $global_context->server->get_channel($channel_name);
		my $latest_message = $channel->message_log->[-1];

		$latest_message->{metadata} = eval { decode_json($msg) };

		return 1;
	}

}
