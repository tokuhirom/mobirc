? my $message = shift;
? strip_nl {

<span class="time">
    <span class="hour"><?= sprintf "%02d", $message->hour ?></span>
    <span class="colon">:</span>
    <span class="minute"><?= sprintf "%02d", $message->minute ?></span>
</span>

? if ($message->who) {
    <span class="<?= $message->who_class ?>">(<?= $message->who ?>)</span>
? }
<span class="<?= $message->class ?>"><?= encoded_string($message->html_body) ?></span>

? }
