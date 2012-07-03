? my ($channels, $has_next_page,) = @_;

? wrap {

? for my $channel (@$channels) {
    <div class="ChannelHeader">
        <a class="ChannelName"><?= $channel->fullname ?></a>
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>&server=<?= $channel->server->id ?>">more...</a>
    </div>
?    for my $message (@{$channel->recent_log}) {
        <?= include('parts/irc_message', $message) ?>
        <br />
?    }
    <hr />
? }

? if ($has_next_page) {
    <?= pictogram(6) ?><a href="/mobile/recent" accesskey="6">next</a>
? }

<hr />

?= include('mobile/_go_to_top')

? }
