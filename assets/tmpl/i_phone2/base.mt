? global_context->mt->wrapper_file('i_phone2/_wrap.mt')->(sub {
<div class="toolbar">
    <h1>mobirc</h1>
</div>

<div id="MiscMenuContainer">
    <input type="button" id="RefreshMenu" value="refresh" />
    <input type="button" id="ClearAllUnread" value="clear all unread" />
</div>

<div id="ChannelList">
<ul>
? for my $channel (global_context->channels_sorted) {
    <li class="arrow channel">
        <a href="/iphone2/channel?channel=<?= $channel->name_urlsafe_encoded ?>&server=<?= $channel->server->id ?>"><?= $channel->fullname ?></a>
        <small class="counter"><?= $channel->unread_lines ?></small>
    </li>
? }
</ul>
</div>

? });
