? my $keyword_recent_num = server->keyword_channel->unread_lines;
? if ($keyword_recent_num > 0) {
    <div class="keyword_recent_notice">
        <a href="#">Keyword(<?= $keyword_recent_num ?>)</a>
    </div>
? }
