? my $channel = shift;
<div>
?   for my $message ($channel->message_log) {
        <?= render_irc_message($message) ?>
        <br />
?   }
</div>
