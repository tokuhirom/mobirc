? my $favorites = ' ' . join(' ', split /\s*,\s*/, lc config->{global}->{favorites}) . ' ';
? my $channels  = [ sort { -($favorites =~ quotemeta(lc $a->name)) <=> -($favorites =~ quotemeta(lc $b->name)) } server->channels_sorted ];
<ul>
? for my $channel (@$channels) {
    <li class="arrow channel">
        <a href="#"><?= $channel->name ?></a>
?     if ($channel->unread_lines) {
            <small class="counter"><?= $channel->unread_lines ?></small>
?     }
    </li>
? }
</ul>
