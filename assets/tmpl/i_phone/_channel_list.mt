? for my $channel (global_context->channels) {
? my $class = $channel->unread_lines ? 'unread channel' : 'channel';
    <div class="<?= $class ?>">
        <a href="#" data-server="<?= $channel->server->id ?>"><?= $channel->name ?></a>
    </div>
? }
