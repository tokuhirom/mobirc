? my $num = server->keyword_channel->unread_lines;
? if ($num) {
    <div class="keyword_recent_notice">
        <a href="#">Keyword(<?= $num ?>)</a>
    </div>
? }
