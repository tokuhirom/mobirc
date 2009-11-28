? my $num = server->keyword_channel->unread_lines;
? if ($num) {
    <ul>
        <li class="arrow"><a href="#">Keyword(<?= $num ?>)</a></li>
    </ul>
? }
