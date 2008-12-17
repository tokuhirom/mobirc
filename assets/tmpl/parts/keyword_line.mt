? my $message = shift;
?= include('parts/irc_message');
? my $channel = $messsage->channel;
(
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">
        <?= $channel->name ?>
    </a>
)
<br />
