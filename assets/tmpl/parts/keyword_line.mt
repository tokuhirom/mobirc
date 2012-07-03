? my $message = shift;
?= include('parts/irc_message', $message);
<? if (my $channel = $message->channel) { ?>
    (
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>&server=<?= $channel->server->id ?>">
            <?= $channel->fullname ?>
        </a>
    )
<? } ?>
<br />
