? wrap {

? my $keyword_recent_num = server->keyword_channel->unread_lines();
? if ($keyword_recent_num) {
    <div class="keyword_recent_notice">
        <a href="/mobile/keyword?recent_mode=on">Keyword(<?= $keyword_recent_num ?>)</a>
    </div>
? }

? for my $channel (server->channels_sorted) {
    <?= pictogram('(^-^)') ?>
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a>
    <? if ($channel->unread_lines) { ?>
        <a href="/mobile/channel?recent_mode=on&channel=<?= $channel->name_urlsafe_encoded ?>">
            <?= $channel->unread_lines ?>
        </a>
    <? }                             ?>
    <br />
? }

<hr />

<?= pictogram('0') ?><a href="/mobile/#top" accesskey="0">refresh list</a><br />
? if (server->has_unread_message) {
    <span>*</span><a href="/mobile/recent" accesskey="*">recent</a><br />
? }
? # TODO: use pictogram for '#' & '*'
<span>#</span><a href="/mobile/topics" accesskey="#">topics</a><br />
<span>!</span><a href="/mobile/keyword" accesskey="!">keyword</a><br />
<span><?= pictogram('9') ?></span><a href="/mobile/clear_all_unread" accesskey="9">clear_all_unread</a><br />

<hr />

App::Mobirc <?= $App::Mobirc::VERSION ?>

? }
