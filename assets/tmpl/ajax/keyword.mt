<div>
?   for my $row ( server->keyword_channel->message_log ) {
        <?= include('parts/keyword_line', $row) ?>
?   }
</div>
