? my ($channel, $channel_page_option) = @_
<html>
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <script src="/static/jquery.js" type="text/javascript"></script>
        <link rel="stylesheet" href="/static/my-site-style.css" type="text/css" />
        <title>Mobirc</title>
    </head>
    <body>
        <div id="content">
            <? my $message     = param('msg') || ''; ?>

            <form action='/my/channel?channel=<?= $channel->name_urlsafe_encoded?>' method='post' id="input">
                <div class="input">
                    <input value="<?= $message ?>" type="text" name="msg" size="10" class="text" />
                </div>
            </form>

            <? my $recent_mode = param('recent_mode'); ?>
            <? if ($channel) { ?>
            <?    if (@{$channel->message_log}) { ?>
            <?       my $meth = $recent_mode ? 'recent_log' : 'message_log'; ?>
            <?       my $i = 0; for my $message (reverse $channel->$meth) { ?>
            <div class="message <?= $message->class ?>">
                <span class="time">
                    <?= sprintf "%02d:%02d", $message->hour, $message->minute ?></span>
                </span>

                <? if ($message->who) { ?>
                <span class="who <?= $message->who_class ?>"><?= $message->who ?></span>
                <? } ?>

                <div class="body"><?= encoded_string($message->html_body) ?></div>
            </div>
            <?       $i++ } ?>
            <?       if ($recent_mode) { ?>
            <div class="more">
                <a href="/my/channel?channel=<?= $channel->name_urlsafe_encoded ?>">More…</a>
            </div>
            <?       } ?>
            <?    } else { ?>
            <p>No message here.</p>
            <?    } ?>
            <? } else { ?>
            <p>No such channel.</p>
            <? } ?>
        </div>
        <script type="text/javascript">
            var docroot = '<?= docroot() ?>';
        </script>
        <script src="/static/my-site-script.js" type="text/javascript"></script>
    </body>
</html>
