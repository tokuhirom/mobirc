package App::Mobirc::Plugin::IRCCommand::Metadata;
use strict;
use App::Mobirc::Plugin;
use App::Mobirc::Util;
use Encode;
use JSON;

hook on_irc_msg => sub {
	my ($self, $global_context, $poe, $who, $targets, $msg) = @_;

	if ($targets->[0] =~ /\@metadata$/) {
		# find latest message
		my $latest_message = [
			sort {
				$b->time <=> $a->time
			}
			map {
				$_->message_log->[-1] || ()
			}
			$global_context->server->channels
		]->[0];
		$latest_message->{metadata} = eval { decode_json($msg) };
	}

}
