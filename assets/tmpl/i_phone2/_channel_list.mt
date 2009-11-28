<ul>
? for my $channel (server->channels) {
    <li class="arrow channel">
        <a href="#"><?= $channel->name ?></a>
?     if ($channel->unread_lines) {
            <small class="counter"><?= $channel->unread_lines ?></small>
?     }
    </li>
? }
</ul>
