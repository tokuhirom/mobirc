? wrap {

? my ($channels, $has_next_page,) = @_;
? for my $channel (@$channels) {
    <div class="ChannelHeader">
        <a class="ChannelName"><?= $channel->name ?></a>
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">more...</a>
    </div>
?    for my $message (@{$channel->recent_log}) {
        <?= render_irc_message($message) ?>
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
