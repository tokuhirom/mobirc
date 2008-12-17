? for my $channel ( server()->channels ) {
?   my $class = $channel->unread_lines ? 'unread channel' : 'channel';
    <div class="<?= $class ?>">
        <a href="#"><?= $channel->name ?></a>
    </div>
? }
