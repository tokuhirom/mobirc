? my $channel = shift;
<div>
?   for my $message ($channel->message_log) {
        <?= include('parts/irc_message', $message) ?>
        <br />
?   }
</div>
