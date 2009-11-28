? use List::MoreUtils qw(any);
? my ($channel, $channel_page_option) = @_;
? my $msg     = param('msg') || '';
? my $page    = param('page') || 1;

<form action='/iphone2/channel' method='post' id="input">
    <div class="input">
        <input type="hidden" name="channel" value="<?= $channel->name ?>" />
        <input value="<?= $msg ?>" type="text" name="msg" size="10" class="text" />
    </div>
</form>

<? if ($channel) { ?>
<?    if (@{$channel->message_log}) { ?>
<?       my $log  = [ reverse $channel->message_log  ] ?>

<div id="content">
    <?   my $i = 0; for my $message (splice @$log, ($page - 1) * 25, 25) { ?>
    <?      my $is_new = any { $message eq $_ } $channel->recent_log; ?>
    <div class="message <?= $message->class ?> <?=  $is_new ? 'new' : ''?>">
        <span class="time">
            <? if (my ($id) = $message->body =~ m{\[([a-z]+)\]}) { ?>
            <select class="operations">
                <option selected="selected" value="">♥♣</option>
                <option value="/me fav <?= $id ?>">fav</option>
            </select>
            <? } ?>

            <?= sprintf "%02d:%02d", $message->hour, $message->minute ?></span>
        </span>

        <? if ($message->who) { ?>
        <span class="who <?= $message->who_class ?>" onclick="document.getElementById('foo').click()">
            <?= $message->who ?>

            <? if ($message->{metadata} && $message->{metadata}->{uri}) { ?>
                <a href="<?= $message->{metadata}->{uri} ?>" class="uri">URI</a>
            <? } ?>

        </span>
        <? } ?>

        <div class="body">
            <?= encoded_string($message->html_body) ?>
        </div>
    </div>
    <?   $i++ } ?>
</div>

<div class="pager">
    <a href="#main" id="showChannelList">
        ← Channel List
    </a>
</div>
<?    } else { ?>
<p>No message here.</p>
<?    } ?>
<? } else { ?>
<p>No such channel.</p>
<? } ?>

<script type="text/javascript">
    var docroot = '<?= docroot() ?>';
</script>
