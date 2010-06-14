? my ($channel, $channel_page_option) = @_

? wrap {

? my $message     = param('msg') || '';
    <form action='/mobile/channel?channel=<?= $channel->name_urlsafe_encoded?>' method='post'>
        <input <? if ($message) { ?>value="<?= $message ?><? } ?>
               type="text" name="msg" size="10" />
        <input type="submit" accesskey="1" value="OK" />
    </form>

? for my $html (@$channel_page_option) {
    <?= $html ?>
? }
    <br />

? my $recent_mode = param('recent_mode');
? if ($channel) {
?    if (@{$channel->message_log}) {
?       my $meth = $recent_mode ? 'recent_log' : 'message_log';
?       for my $message (reverse $channel->$meth) {
            <?= include('parts/irc_message', $message) ?>
            <br />
?       }
?       if ($recent_mode) {
            <hr />
            <?= pictogram('5') ?><a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>" accesskey="5">more</a>
?       }
?    } else {
        <p>no message here</p>
?    }
    <hr />
    <a href="/mobile/members?channel=<?= $channel->name_urlsafe_encoded ?>">members</a>
? } else {
    <p>no such channel.</p>
? }

<hr />

?= include('mobile/_go_to_top')

? }
